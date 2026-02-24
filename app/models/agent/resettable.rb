module Agent::Resettable
  extend ActiveSupport::Concern

  def wipe_memory(since: nil)
    transaction do
      if since
        wipe_memory_since(since)
      else
        wipe_all_memory
      end
    end
  end

  def factory_reset
    transaction do
      wipe_all_memory
      chats.destroy_all
      custom_apps.destroy_all
    end
    reset_workspace if workspace_enabled?
  end

  private
    def wipe_all_memory
      memories.destroy_all
      chats.each { |chat| chat.messages.destroy_all }
    end

    def wipe_memory_since(cutoff)
      memories.where(created_at: cutoff..).destroy_all

      chats.each do |chat|
        chat.messages.where(created_at: cutoff..).destroy_all
      end

      chats.left_joins(:messages).where(messages: { id: nil }).destroy_all
    end

    def reset_workspace
      workspace = Agent::Workspace.new(self)
      workspace.destroy
      FileUtils.rm_rf(workspace.path)
      FileUtils.rm_rf(workspace.home_path)
      workspace.start
    end
end
