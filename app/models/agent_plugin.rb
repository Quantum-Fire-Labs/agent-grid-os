class AgentPlugin < ApplicationRecord
  belongs_to :agent
  belongs_to :plugin

  validate :network_mode_compatible

  after_create_commit :setup_workspace
  after_destroy_commit :teardown_workspace

  private
    def network_mode_compatible
      return if plugin.blank?
      return if plugin.compatible_with_network_mode?(agent.network_mode)

      if plugin.requires_full_network?
        errors.add(:base, "#{plugin.name} requires full network access, but agent network mode is #{agent.network_mode}")
      else
        errors.add(:base, "#{plugin.name} requires network access incompatible with agent network mode #{agent.network_mode}")
      end
    end

    def setup_workspace
      return unless agent.workspace_enabled?

      install_packages if plugin.packages.any?
      recreate_workspace if plugin.mounts.any?
    end

    def teardown_workspace
      return unless agent.workspace_enabled?

      recreate_workspace if plugin.mounts.any?
    end

    def install_packages
      workspace = Agent::Workspace.new(agent)
      packages = plugin.packages.join(" ")
      workspace.exec("apt-get update -qq && apt-get install -y -qq #{packages}", timeout: 120)
    end

    def recreate_workspace
      workspace = Agent::Workspace.new(agent)
      workspace.destroy
      workspace.start
    end
end
