class Chat < ApplicationRecord
  include Chat::Speakable

  MENTION_TOKEN = /@([A-Za-z0-9_]+)/

  belongs_to :account
  has_many :participants, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :users, through: :participants, source: :participatable, source_type: "User"
  has_many :agents, through: :participants, source: :participatable, source_type: "Agent"

  def display_name(viewer: nil)
    return title if title.present?

    names = participant_display_names
    if viewer.is_a?(User)
      viewer_name = viewer.full_name
      names = names - [ viewer_name ] if names.size > 1
    end

    names.presence&.join(", ") || "Untitled Chat"
  end

  def participant_display_names
    participants.includes(:participatable).filter_map do |participant|
      entity = participant.participatable
      next unless entity

      if entity.is_a?(User)
        entity.full_name
      else
        entity.name
      end
    end
  end

  def group?
    participants.count >= 3
  end

  def direct?
    participants.count == 2
  end

  def agent
    agents.first
  end

  def last_message
    @last_message ||= messages.order(created_at: :desc).first
  end

  def halt!
    update!(halted_at: Time.current)
    Turbo::StreamsChannel.broadcast_stream_to(self, content: <<~TURBO)
      <turbo-stream action="remove" targets="[id^='streaming-message-']"><template></template></turbo-stream>
      <turbo-stream action="remove" target="typing-indicator"><template></template></turbo-stream>
    TURBO
  end

  def halted?
    halted_at.present?
  end

  def enqueue_agent_replies_for(message, tts_enabled: false)
    return unless message.role == "user"
    return unless message.sender.is_a?(User)

    reply_agents_for(message).each do |reply_agent|
      enqueue_agent_reply(agent: reply_agent, tts_enabled: tts_enabled)
    end
  end

  def generate_agent_reply(agent:, tts_enabled: false)
    update!(halted_at: nil)
    brain = Agent::Brain.new(agent, self)
    last_user_message = messages.where(role: "user").order(:created_at).last
    last_user_content = last_user_message&.content

    if last_user_message&.audio&.attached?
      last_user_content = "#{last_user_content}\n\n(Sent as voice memo. Keep response concise — it will be read aloud.)"
    end

    accumulated = +""
    streaming = false
    stream_id = SecureRandom.hex(4)
    tts = nil

    reset_streaming = lambda do
      tts&.reset(accumulated)
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "streaming-message-#{stream_id}") if streaming
      accumulated.clear
      streaming = false
      stream_id = SecureRandom.hex(4)
    end

    typing_indicator_html = <<~HTML
      <div class="chat-typing" id="typing-indicator">
        <div class="chat-msg-gutter">
          <div class="chat-avatar chat-avatar-agent">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="5" stroke="currentColor" stroke-width="1.2"/>
              <circle cx="7" cy="7" r="1.5" fill="currentColor"/>
            </svg>
          </div>
        </div>
        <div class="chat-msg-body">
          <div class="chat-msg-meta">
            <span class="chat-msg-sender">#{ERB::Util.html_escape(agent.name)}</span>
          </div>
          <div class="chat-typing-dots">
            <span></span><span></span><span></span>
          </div>
        </div>
      </div>
    HTML

    pending_tool_messages = []
    show_typing_indicator = lambda do
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")
      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        html: typing_indicator_html
      )
    end

    on_message = lambda do |msg|
      reset_streaming.call
      if msg.role == "tool"
        pending_tool_messages << msg
      else
        Turbo::StreamsChannel.broadcast_append_to(
          self,
          target: "chat-messages",
          partial: "chats/messages/message",
          locals: { message: msg, agent: agent }
        )
      end
    end

    on_tool_complete = lambda do
      stream_content = +""
      pending_tool_messages.each do |msg|
        html = ApplicationController.render(
          partial: "chats/messages/message",
          locals: { message: msg, agent: agent }
        )
        stream_content << "<turbo-stream action=\"append\" target=\"chat-messages\"><template>#{html}</template></turbo-stream>"
      end
      stream_content << "<turbo-stream action=\"remove\" target=\"typing-indicator\"></turbo-stream>"
      stream_content << "<turbo-stream action=\"append\" target=\"chat-messages\"><template>#{typing_indicator_html}</template></turbo-stream>"
      Turbo::StreamsChannel.broadcast_stream_to(self, content: stream_content)
      pending_tool_messages.clear
    end

    tts = start_tts_stream if tts_enabled
    show_typing_indicator.call

    message = brain.respond(
      user_message: last_user_content,
      user_message_record: last_user_message,
      on_message: on_message,
      on_tool_complete: on_tool_complete
    ) do |token|
      accumulated << token
      tts&.feed(accumulated)

      unless streaming
        begin
          Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")
          Turbo::StreamsChannel.broadcast_append_to(
            self,
            target: "chat-messages",
            partial: "chats/messages/streaming",
            locals: { agent: agent, stream_id: stream_id, content: MarkdownHelper.to_html(accumulated).html_safe }
          )
          streaming = true
          next
        rescue => e
          Rails.logger.warn("Streaming shell failed: #{e.message}")
          next
        end
      end

      begin
        Turbo::StreamsChannel.broadcast_update_to(
          self,
          target: "streaming-content-#{stream_id}",
          html: MarkdownHelper.to_html(accumulated)
        )
      rescue => e
        Rails.logger.warn("Streaming token failed: #{e.message}")
        streaming = false
      end
    end

    Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")

    if streaming
      Turbo::StreamsChannel.broadcast_replace_to(
        self,
        target: "streaming-message-#{stream_id}",
        partial: "chats/messages/message",
        locals: { message: message, agent: agent }
      )
    else
      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        partial: "chats/messages/message",
        locals: { message: message, agent: agent }
      )
    end

    tts&.finish(message)
  rescue Providers::Error => e
    Rails.logger.error("generate_agent_reply provider error: #{e.message}")
    broadcast_error(e.message, stream_id: stream_id)
  rescue StandardError => e
    Rails.logger.error("generate_agent_reply failed: #{e.class} - #{e.message}")
    broadcast_error(e.message, stream_id: stream_id)
  end

  def enqueue_agent_reply(agent:, tts_enabled: false)
    Agent::ReplyJob.perform_later(self, agent: agent, tts_enabled: tts_enabled)
  end

  private
    def broadcast_error(message, stream_id: nil)
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "streaming-message-#{stream_id}") if stream_id
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")

      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        partial: "chats/messages/error",
        locals: { error: message }
      )
    end

    def reply_agents_for(message)
      present_agents = agents.to_a
      return [] if present_agents.empty?
      return present_agents if present_agents.one?

      tagged_tokens = mentioned_tokens(message.content)
      present_agents.select { |a| tagged_tokens.include?(mention_token_for_agent(a)) }
    end

    def mentioned_tokens(content)
      (content || "").scan(MENTION_TOKEN).flatten.map { |token| normalize_mention_token(token) }.uniq
    end

    def mention_token_for_agent(agent)
      normalize_mention_token(agent.name)
    end

    def normalize_mention_token(text)
      text.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
end
