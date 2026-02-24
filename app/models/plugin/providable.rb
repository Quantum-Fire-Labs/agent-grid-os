module Plugin::Providable
  extend ActiveSupport::Concern

  def provider?
    provider_config.present?
  end

  def provider_mode?(agent)
    provider? && resolve_config("MODE", agent: agent) == "provider"
  end

  def provider_entrypoint_class
    return nil unless provider?

    entrypoint_file = provider_config["entrypoint"]
    require path.join(entrypoint_file).to_s
    name.classify.constantize
  end
end
