class Chats::Messages::SpeechesController < ApplicationController
  include ChatAccessible

  before_action :set_chat
  before_action :require_chat_participant
  before_action :set_message
  before_action :set_agent

  def create
    if @message.audio.attached?
      return render json: { url: rails_blob_path(@message.audio, only_path: true) }
    end

    synthesize_and_attach
  rescue Providers::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def regenerate
    @message.audio.purge if @message.audio.attached?
    synthesize_and_attach
  rescue Providers::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private
    def synthesize_and_attach
      mp3_data = Agent::Audio.new(@agent).speak(@message.content)

      @message.audio.attach(
        io: StringIO.new(mp3_data),
        filename: "speech_#{@message.id}.mp3",
        content_type: "audio/mpeg"
      )

      render json: { url: rails_blob_path(@message.audio, only_path: true) }
    end

    def set_chat
      @chat = Chat.find(params[:chat_id])
    end

    def set_message
      @message = @chat.messages.find(params[:message_id])
    end

    def set_agent
      @agent = @message.sender if @message.sender.is_a?(Agent)
      @agent ||= @chat.agent
      head :unprocessable_entity unless @agent
    end
end
