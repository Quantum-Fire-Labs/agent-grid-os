class Chats::MessagesController < ApplicationController
  include ChatAccessible

  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  before_action :set_chat
  before_action :require_chat_participant
  before_action :set_message, only: :destroy

  def index
    scope = @chat.messages.order(created_at: :desc)
    scope = scope.where("created_at < ?", Time.parse(params[:before])) if params[:before]
    @messages = scope.limit(50).reverse
    @has_older = scope.offset(50).exists?
    @primary_agent = @chat.agent
    @tts_available = @primary_agent.present? && Agent::Audio.new(@primary_agent).available?

    render partial: "chats/messages/batch",
           locals: { messages: @messages, agent: @primary_agent, has_older: @has_older, tts_available: @tts_available }
  end

  def create
    message_params = params.expect(message: [ :content ])
    content = message_params[:content]
    audio = params.dig(:message, :audio)
    tts_enabled = params[:tts] == "1"

    if audio.present?
      transcription_agent = @chat.agent
      return head :unprocessable_entity unless transcription_agent

      transcript = Agent::Audio.new(transcription_agent).transcribe(audio, filename: audio.original_filename)
      content = transcript
      tts_enabled = true
    end

    @message = @chat.messages.create!(
      role: "user",
      content: content,
      sender: Current.user
    )
    @message.audio.attach(audio) if audio.present?

    message_html = ApplicationController.render(
      partial: "chats/messages/message",
      locals: { message: @message, agent: @chat.agent, tts_available: tts_available_for_chat? }
    )

    stream_content = +"<turbo-stream action=\"remove\" target=\"chat-welcome\"><template></template></turbo-stream>"
    stream_content << "<turbo-stream action=\"append\" target=\"chat-messages\"><template>#{message_html}</template></turbo-stream>"
    Turbo::StreamsChannel.broadcast_stream_to(@chat, content: stream_content)

    @chat.enqueue_agent_replies_for(@message, tts_enabled: tts_enabled)

    head :ok
  end

  def destroy
    @message.destroy!
    Turbo::StreamsChannel.broadcast_remove_to(@chat, target: ActionView::RecordIdentifier.dom_id(@message))
    head :ok
  end

  private
    def set_chat
      @chat = Chat.find(params[:chat_id])
    end

    def set_message
      @message = @chat.messages.find(params[:id])
    end

    def tts_available_for_chat?
      @tts_available_for_chat ||= @chat.agent.present? && Agent::Audio.new(@chat.agent).available?
    end
end
