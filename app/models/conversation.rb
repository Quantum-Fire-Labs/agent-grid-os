class Conversation < ApplicationRecord
  include Speakable

  belongs_to :agent
  has_many :messages, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :users, through: :participants

  enum :kind, %w[direct group].index_by(&:itself), default: "direct", prefix: true

  def self.direct_with(user)
    joins(:participants)
      .where(kind: "direct", participants: { user_id: user.id })
      .first
  end

  def self.find_or_create_direct(user)
    direct_with(user) || create!(kind: "direct").tap do |conversation|
      conversation.participants.create!(user: user)
    end
  end

  def display_name
    kind_direct? ? agent.name : users.map(&:first_name).join(", ")
  end

  def last_message
    @last_message ||= messages.order(created_at: :desc).first
  end

  def generate_agent_reply(tts_enabled: false)
    brain = Agent::Brain.new(agent, self)
    last_user_message = messages.where(role: "user").order(:created_at).last
    last_user_content = last_user_message&.content

    if last_user_message&.audio&.attached?
      last_user_content = "#{last_user_content}\n\n(Sent as voice memo. Keep response concise — it will be read aloud.)"
    end

    accumulated = +""
    streaming = false
    stream_id = SecureRandom.hex(4)
    helpers = ApplicationController.helpers
    tts = nil

    reset_streaming = -> do
      tts&.reset(accumulated)
      if streaming
        Turbo::StreamsChannel.broadcast_remove_to(self, target: "streaming-message-#{stream_id}")
      end
      accumulated.clear
      streaming = false
      stream_id = SecureRandom.hex(4)
    end

    on_message = ->(msg) do
      reset_streaming.call
      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        partial: "agents/conversations/messages/message",
        locals: { message: msg, agent: agent }
      )
    end

    on_tool_complete = -> do
      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        html: <<~HTML
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
      )
    end

    tts = start_tts_stream if tts_enabled

    message = brain.respond(user_message: last_user_content, user_message_record: last_user_message, on_message: on_message, on_tool_complete: on_tool_complete) do |token|
      accumulated << token

      tts&.feed(accumulated)

      unless streaming
        begin
          Turbo::StreamsChannel.broadcast_replace_to(
            self,
            target: "typing-indicator",
            partial: "agents/conversations/messages/streaming",
            locals: { agent: agent, stream_id: stream_id, content: helpers.simple_format(helpers.sanitize(accumulated)) }
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
          html: helpers.simple_format(helpers.sanitize(accumulated))
        )
      rescue => e
        Rails.logger.warn("Streaming token failed: #{e.message}")
        streaming = false
      end
    end

    Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")

    if streaming
      # Replace streaming wrapper with the full message partial
      Turbo::StreamsChannel.broadcast_replace_to(
        self,
        target: "streaming-message-#{stream_id}",
        partial: "agents/conversations/messages/message",
        locals: { message: message, agent: agent }
      )
    else
      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        partial: "agents/conversations/messages/message",
        locals: { message: message, agent: agent }
      )
    end

    tts&.finish(message)
  rescue Providers::Error => e
    Rails.logger.error("generate_agent_reply provider error: #{e.message}")
    broadcast_error("Provider error: #{e.message}", stream_id: stream_id)
  rescue StandardError => e
    Rails.logger.error("generate_agent_reply failed: #{e.class} - #{e.message}")
    broadcast_error(e.message, stream_id: stream_id)
  end

  def enqueue_agent_reply(tts_enabled: false)
    Agent::ReplyJob.perform_later(self, tts_enabled: tts_enabled)
  end

  private

    def dom_id(record, prefix = nil)
      ActionView::RecordIdentifier.dom_id(record, prefix)
    end

    def broadcast_error(message, stream_id: nil)
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "streaming-message-#{stream_id}") if stream_id
      Turbo::StreamsChannel.broadcast_remove_to(self, target: "typing-indicator")

      Turbo::StreamsChannel.broadcast_append_to(
        self,
        target: "chat-messages",
        partial: "agents/conversations/messages/error",
        locals: { error: message }
      )
    end
end
