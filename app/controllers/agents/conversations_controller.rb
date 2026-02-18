class Agents::ConversationsController < ApplicationController
  include AgentAccessible

  rate_limit to: 10, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  before_action :set_agent
  def index
    @conversations = @agent.conversations
      .joins(:participants)
      .where(participants: { user_id: Current.user.id })
      .includes(:users, :messages)
      .order(updated_at: :desc)
  end

  def create
    @conversation = @agent.conversations.create!(kind: "group")
    @conversation.participants.create!(user: Current.user)
    redirect_to chat_path(@conversation)
  end

  private

    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end

end
