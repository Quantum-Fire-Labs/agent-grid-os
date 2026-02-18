class MigrateProviderApiKeysToKeyChains < ActiveRecord::Migration[8.1]
  def up
    Provider.find_each do |provider|
      next unless provider.api_key.present?
      KeyChain.find_or_create_by!(
        owner_type: provider.providerable_type,
        owner_id: provider.providerable_id,
        name: provider.name
      ) do |kc|
        kc.secrets = { "api_key" => provider.api_key }
      end
    end
    remove_column :providers, :api_key, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
