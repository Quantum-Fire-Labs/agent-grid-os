class ChatsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to chats_path, alert: "Too many requests. Try again later." }

  before_action :set_chats
  before_action :set_chat, only: :show

  def index
    @chat ||= @chats.first
    prepare_chat if @chat
  end

  def show
    prepare_chat
    render :index
  end

  def create
    return redirect_to chats_path, alert: "Not authorized" unless Current.user.admin?

    agent = Current.account.agents.first
    return redirect_to chats_path, alert: "No agents available" unless agent

    chat = agent.find_or_create_direct_chat(Current.user)
    redirect_to chat_path(chat)
  end

  private
    def set_chats
      @chats = Current.user.chats
        .includes(:messages)
        .preload(participants: :participatable)
        .order(updated_at: :desc)
    end

    def set_chat
      @chat = Current.user.chats.find_by(id: params[:id])
      return if @chat

      redirect_to chats_path
    end

    def prepare_chat
      @agent = @chat.agent
      @messages = @chat.messages.order(created_at: :desc).limit(50).reverse
      @has_older = @messages.any? && @chat.messages.where("created_at < ?", @messages.first.created_at).exists?
      @audio_available = @agent.present? && Agent::Audio.new(@agent).available?
      @available_users = Current.account.users.where.not(id: @chat.users.select(:id)) if @chat.group?
    end
end
