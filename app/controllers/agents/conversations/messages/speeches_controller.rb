class Agents::Conversations::Messages::SpeechesController < ApplicationController
  include ConversationAccessible

  before_action :set_agent
  before_action :set_conversation
  before_action :require_participant
  before_action :set_message

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
      audio_service = Agent::Audio.new(@agent)
      mp3_data = audio_service.speak(@message.content)

      @message.audio.attach(
        io: StringIO.new(mp3_data),
        filename: "speech_#{@message.id}.mp3",
        content_type: "audio/mpeg"
      )

      render json: { url: rails_blob_path(@message.audio, only_path: true) }
    end

    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def set_conversation
      @conversation = @agent.conversations.find(params[:conversation_id])
    end


    def set_message
      @message = @conversation.messages.find(params[:message_id])
    end
end
