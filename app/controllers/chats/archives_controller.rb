class Chats::ArchivesController < ApplicationController
  include ChatAccessible

  before_action :set_chat
  before_action :require_chat_participant

  def create
    @chat.archive!
    redirect_to chats_path
  end

  def destroy
    @chat.unarchive!
    redirect_to chats_path(archived: 1)
  end

  private
    def set_chat
      @chat = Chat.find(params[:chat_id])
    end
end
