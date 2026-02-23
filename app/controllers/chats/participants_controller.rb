class Chats::ParticipantsController < ApplicationController
  include ChatAccessible

  before_action :require_admin
  before_action :set_chat
  before_action :require_chat_participant

  def create
    attrs = participant_params

    if attrs[:user_id].present?
      user = Current.account.users.find(attrs[:user_id])
      @chat.participants.create!(participatable: user)
    elsif attrs[:agent_id].present?
      agent = Current.account.agents.find(attrs[:agent_id])
      @chat.participants.create!(participatable: agent)
    else
      return redirect_to chat_path(@chat), alert: "Select a user or agent."
    end

    redirect_to chat_path(@chat)
  end

  def destroy
    @chat.participants.find(params[:id]).destroy!
    redirect_to chat_path(@chat)
  end

  private
    def set_chat
      @chat = Chat.find(params[:chat_id])
    end

    def participant_params
      params.expect(participant: [ :user_id, :agent_id ])
    end
end
