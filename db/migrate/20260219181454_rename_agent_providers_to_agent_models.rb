class RenameAgentProvidersToAgentModels < ActiveRecord::Migration[8.1]
  def change
    rename_table :agent_providers, :agent_models
    add_column :agent_models, :model, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE agent_models
          SET model = (SELECT providers.model FROM providers WHERE providers.id = agent_models.provider_id)
        SQL

        # Replace "none" designations with "fallback" since AgentModel only uses default/fallback
        execute "UPDATE agent_models SET designation = 'fallback' WHERE designation = 'none'"
      end
    end

    change_column_null :agent_models, :model, false
    change_column_default :agent_models, :designation, from: "none", to: "fallback"
  end
end
