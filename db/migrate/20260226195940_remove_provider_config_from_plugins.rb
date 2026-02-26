class RemoveProviderConfigFromPlugins < ActiveRecord::Migration[8.1]
  def change
    remove_column :plugins, :provider_config, :json
  end
end
