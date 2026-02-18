module CustomApp::Servable
  extend ActiveSupport::Concern

  def workspace_path
    Agent::Workspace.new(agent).path.join(path)
  end

  def entrypoint_path
    workspace_path.join(entrypoint)
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

    full_path = workspace_path.join(clean_path)
    return nil unless full_path.to_s.start_with?(workspace_path.to_s)
    return nil unless full_path.exist?
    return nil unless full_path.file?

    full_path
  end
end
