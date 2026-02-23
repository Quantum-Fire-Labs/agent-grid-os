module CustomApp::Servable
  extend ActiveSupport::Concern

  def storage_path
    Rails.root.join("storage", "apps", id.to_s)
  end

  def files_path
    storage_path.join("files")
  end

  def entrypoint_path
    files_path.join(entrypoint)
  end

  def entrypoint_content
    return nil unless entrypoint_path.exist?
    entrypoint_path.read
  end

  def resolve_asset(relative_path)
    return nil if relative_path.blank?
    return nil if relative_path.include?("..")

    clean_path = Pathname.new(relative_path).cleanpath
    return nil if clean_path.to_s.start_with?("/")

    full_path = files_path.join(clean_path)
    return nil unless full_path.to_s.start_with?(files_path.to_s)
    return nil unless full_path.exist?
    return nil unless full_path.file?

    full_path
  end
end
