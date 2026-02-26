class CreateScheduledActions < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_actions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.references :chat, null: true, foreign_key: true
      t.references :created_by_user, null: true, foreign_key: { to_table: :users }
      t.references :created_from_message, null: true, foreign_key: { to_table: :messages }
      t.string :title, null: false
      t.string :status, null: false, default: "active"
      t.string :run_mode, null: false
      t.string :schedule_kind, null: false
      t.string :timezone, null: false
      t.datetime :one_time_run_at
      t.json :recurrence_rule, null: false, default: {}
      t.datetime :starts_at
      t.datetime :ends_at
      t.json :payload, null: false, default: {}
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.string :last_run_status
      t.text :last_error
      t.datetime :canceled_at
      t.datetime :paused_at
      t.timestamps
    end

    add_index :scheduled_actions, [ :status, :next_run_at ]
    add_index :scheduled_actions, :next_run_at

    create_table :scheduled_action_runs do |t|
      t.references :scheduled_action, null: false, foreign_key: true
      t.datetime :scheduled_for_at, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :status, null: false
      t.text :error
      t.text :result_summary
      t.references :delivery_message, null: true, foreign_key: { to_table: :messages }
      t.string :queue_job_id
      t.timestamps
    end

    add_index :scheduled_action_runs, [ :scheduled_action_id, :scheduled_for_at ],
      unique: true,
      name: "idx_scheduled_action_runs_unique_occurrence"
    add_index :scheduled_action_runs, :status
    add_index :scheduled_action_runs, :scheduled_for_at

    add_check_constraint :scheduled_actions,
      "status IN ('active','paused','canceled','completed')",
      name: "scheduled_actions_status_check"
    add_check_constraint :scheduled_actions,
      "run_mode IN ('chat_trigger','direct_tool')",
      name: "scheduled_actions_run_mode_check"
    add_check_constraint :scheduled_actions,
      "schedule_kind IN ('once','recurring')",
      name: "scheduled_actions_schedule_kind_check"
    add_check_constraint :scheduled_actions,
      "last_run_status IS NULL OR last_run_status IN ('succeeded','failed')",
      name: "scheduled_actions_last_run_status_check"
    add_check_constraint :scheduled_action_runs,
      "status IN ('running','succeeded','failed','canceled','skipped')",
      name: "scheduled_action_runs_status_check"
  end
end
