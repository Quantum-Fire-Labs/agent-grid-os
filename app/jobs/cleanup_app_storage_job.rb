class CleanupAppStorageJob < ApplicationJob
  def perform(path)
    dir = Pathname.new(path)
    FileUtils.rm_rf(dir) if dir.exist?
  end
end
