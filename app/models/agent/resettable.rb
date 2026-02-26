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
    end

    destroy_custom_apps_for_factory_reset

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

    def destroy_custom_apps_for_factory_reset
      apps = custom_apps.to_a
      return if apps.empty?

      app_ids = apps.map(&:id)
      storage_paths = apps.map { |app| app.storage_path.to_s }

      CustomAppAgentAccess.where(custom_app_id: app_ids).delete_all
      CustomAppUser.where(custom_app_id: app_ids).delete_all
      ActiveStorage::Attachment.where(record_type: "CustomApp", record_id: app_ids).delete_all
      CustomApp.where(id: app_ids).delete_all

      storage_paths.each do |path|
        CleanupAppStorageJob.perform_later(path)
      end
    end
end
