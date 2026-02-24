module Plugin::Installable
  extend ActiveSupport::Concern

  class ManifestError < StandardError; end

  class_methods do
    def install_from(account:, source_path:)
      manifest = parse_manifest(source_path)
      plugin = account.plugins.find_or_initialize_by(name: manifest["name"])
      plugin.assign_attributes_from_manifest(manifest)
      plugin.save!
      plugin.copy_files_from(source_path)
      plugin
    end

    private
      def parse_manifest(source_path)
        manifest_path = File.join(source_path, "plugin.yaml")
        raise ManifestError, "plugin.yaml not found in #{source_path}" unless File.exist?(manifest_path)

        require "yaml"
        manifest = YAML.safe_load_file(manifest_path)
        raise ManifestError, "plugin.yaml is empty" if manifest.blank?

        validate_manifest!(manifest)
        manifest
      end

      def validate_manifest!(manifest)
        %w[name].each do |field|
          raise ManifestError, "Missing required field: #{field}" if manifest[field].blank?
        end
      end
  end

  def assign_attributes_from_manifest(manifest)
    assign_attributes(
      plugin_type: manifest["type"] || "tool",
      version: manifest["version"] || "1.0.0",
      description: manifest["description"],
      execution: manifest["execution"] || "sandbox",
      entrypoint: manifest["entrypoint"],
      tools: manifest["tools"] || [],
      permissions: manifest["permissions"] || {},
      config_schema: manifest["config"] || [],
      packages: manifest["packages"] || [],
      mounts: manifest["mounts"] || [],
      provider_config: manifest["provider"]
    )
  end

  def copy_files_from(source_path)
    FileUtils.rm_rf(path)
    FileUtils.mkdir_p(path)
    FileUtils.cp_r(Dir.glob(File.join(source_path, "*")), path)
  end
end
