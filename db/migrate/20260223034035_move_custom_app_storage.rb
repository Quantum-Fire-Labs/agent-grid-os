class MoveCustomAppStorage < ActiveRecord::Migration[8.1]
  def up
    change_column_null :custom_apps, :path, true

    CustomApp.find_each do |app|
      old_files = Rails.root.join("storage", "agents", app.agent_id.to_s, "workspace", app.path)
      new_files = Rails.root.join("storage", "apps", app.id.to_s, "files")

      if old_files.exist? && !new_files.exist?
        FileUtils.mkdir_p(new_files)
        FileUtils.cp_r(old_files.children, new_files)
      end

      old_db = Rails.root.join("storage", "agents", app.agent_id.to_s, "app_data", "#{app.id}.db")
      new_db = Rails.root.join("storage", "apps", app.id.to_s, "data.db")

      if old_db.exist? && !new_db.exist?
        FileUtils.mkdir_p(new_db.dirname)
        FileUtils.cp(old_db, new_db)
        %w[-wal -shm].each do |suffix|
          wal = Pathname.new("#{old_db}#{suffix}")
          FileUtils.cp(wal, "#{new_db}#{suffix}") if wal.exist?
        end
      end
    end
  end

  def down
    change_column_null :custom_apps, :path, false
  end
end
