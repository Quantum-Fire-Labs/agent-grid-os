class Agents::Conversations::MessagesController < ApplicationController
  include ConversationAccessible

  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  before_action :set_agent
  before_action :set_conversation
  before_action :require_participant
  before_action :set_message, only: :destroy

  def index
    scope = @conversation.messages.order(created_at: :desc)
    scope = scope.where("created_at < ?", Time.parse(params[:before])) if params[:before]
    @messages = scope.limit(50).reverse
    @has_older = scope.offset(50).exists?

    render partial: "agents/conversations/messages/batch",
           locals: { messages: @messages, agent: @agent, has_older: @has_older }
  end

  def create
    message_params = params.expect(message: [ :content ])
    content = message_params[:content]
    audio = params.dig(:message, :audio)
    tts_enabled = params[:tts] == "1"

    if audio.present?
      transcript = Agent::Audio.new(@agent).transcribe(audio, filename: audio.original_filename)
      content = transcript
      tts_enabled = true
    end

    @message = @conversation.messages.create!(
      role: "user",
      content: content,
      user: Current.user
    )

    @message.audio.attach(audio) if audio.present?

    agent_tagged = @conversation.kind_direct? || content&.match?(/@#{Regexp.escape(@agent.name)}\b/)

    message_html = ApplicationController.render(
      partial: "agents/conversations/messages/message",
      locals: { message: @message, agent: @agent }
    )

    typing_html = if agent_tagged
      <<~HTML
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
              <span class="chat-msg-sender">#{ERB::Util.html_escape(@agent.name)}</span>
            </div>
            <div class="chat-typing-dots">
              <span></span><span></span><span></span>
            </div>
          </div>
        </div>
      HTML
    end

    stream_content = +"<turbo-stream action=\"remove\" target=\"chat-welcome\"><template></template></turbo-stream>"
    stream_content << "<turbo-stream action=\"append\" target=\"chat-messages\"><template>#{message_html}</template></turbo-stream>"
    stream_content << "<turbo-stream action=\"append\" target=\"chat-messages\"><template>#{typing_html}</template></turbo-stream>" if typing_html

    Turbo::StreamsChannel.broadcast_stream_to(@conversation, content: stream_content)

    @conversation.enqueue_agent_reply(tts_enabled: tts_enabled) if agent_tagged

    head :ok
  end

  def destroy
    return head :forbidden if @conversation.kind_group?

    @message.destroy!
    Turbo::StreamsChannel.broadcast_remove_to(@conversation, target: ActionView::RecordIdentifier.dom_id(@message))

    head :ok
  end

  private

    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def set_conversation
      @conversation = @agent.conversations.find(params[:conversation_id])
    end

    def set_message
      @message = @conversation.messages.find(params[:id])
    end
end
