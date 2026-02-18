class Agents::Conversations::ParticipantsController < ApplicationController
  before_action :require_admin
  before_action :set_agent
  before_action :set_conversation

  def create
    user_id = params.expect(participant: [ :user_id ])[:user_id]
    user = Current.account.users.find(user_id)

    unless user.admin? || @agent.agent_users.exists?(user_id: user.id)
      redirect_to chat_path(@conversation), alert: "User doesn't have access to this agent."
      return
    end

    @conversation.participants.create!(user: user)
    redirect_to chat_path(@conversation)
  end

  def destroy
    @conversation.participants.find(params[:id]).destroy
    redirect_to chat_path(@conversation)
  end

  private

    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def set_conversation
      @conversation = @agent.conversations.find(params[:conversation_id])
    end
end
