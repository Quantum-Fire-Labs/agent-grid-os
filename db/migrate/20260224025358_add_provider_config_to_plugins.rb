class AddProviderConfigToPlugins < ActiveRecord::Migration[8.1]
  def change
    add_column :plugins, :provider_config, :json
  end
end
