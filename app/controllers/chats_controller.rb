class ChatsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to chats_path, alert: "Too many requests. Try again later." }

  before_action :set_conversations
  before_action :set_conversation, only: :show

  def index
    @conversation ||= @conversations.first
    prepare_chat if @conversation
  end

  def show
    prepare_chat
    render :index
  end

  def create
    return redirect_to chats_path, alert: "Not authorized" unless Current.user.admin?

    agent = Current.account.agents.first
    return redirect_to chats_path, alert: "No agents available" unless agent

    conversation = agent.conversations.create!(kind: "group")
    conversation.participants.create!(user: Current.user)
    redirect_to chat_path(conversation)
  end

  private
    def set_conversations
      @conversations = Current.user.conversations
        .includes(:agent, :users)
        .order(updated_at: :desc)
    end

    def set_conversation
      @conversation = Current.user.conversations.find(params[:id])
    end

    def prepare_chat
      @agent = @conversation.agent
      @messages = @conversation.messages.order(created_at: :desc).limit(50).reverse
      @has_older = @messages.any? && @conversation.messages.where("created_at < ?", @messages.first.created_at).exists?
      @audio_available = Agent::Audio.new(@agent).available?
      @available_users = Current.account.users.where.not(id: @conversation.user_ids) if @conversation.kind_group?
    end
end
