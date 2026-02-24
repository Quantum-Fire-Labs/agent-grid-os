class Chats::HaltsController < ApplicationController
  include ChatAccessible

  before_action :set_chat
  before_action :require_chat_participant

  def create
    @chat.halt!
    head :ok
  end

  private
    def set_chat
      @chat = Chat.find(params[:chat_id])
    end
end
