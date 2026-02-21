# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_21_184544) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_models", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "designation", default: "fallback", null: false
    t.string "model", null: false
    t.integer "provider_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "designation"], name: "index_agent_models_on_agent_id_and_designation"
    t.index ["agent_id", "provider_id"], name: "index_agent_models_on_agent_id_and_provider_id", unique: true
    t.index ["agent_id"], name: "index_agent_models_on_agent_id"
    t.index ["provider_id"], name: "index_agent_models_on_provider_id"
  end

  create_table "agent_plugins", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.integer "plugin_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "plugin_id"], name: "index_agent_plugins_on_agent_id_and_plugin_id", unique: true
    t.index ["agent_id"], name: "index_agent_plugins_on_agent_id"
    t.index ["plugin_id"], name: "index_agent_plugins_on_plugin_id"
  end

  create_table "agent_users", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["agent_id", "user_id"], name: "index_agent_users_on_agent_id_and_user_id", unique: true
    t.index ["agent_id"], name: "index_agent_users_on_agent_id"
    t.index ["user_id"], name: "index_agent_users_on_user_id"
  end

  create_table "agents", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "instructions"
    t.string "model"
    t.string "name"
    t.string "network_mode"
    t.text "personality"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.boolean "workspace_enabled", default: false, null: false
    t.index ["account_id"], name: "index_agents_on_account_id"
  end

  create_table "configs", force: :cascade do |t|
    t.integer "configurable_id", null: false
    t.string "configurable_type", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["configurable_type", "configurable_id", "key"], name: "index_configs_on_configurable_type_and_configurable_id_and_key", unique: true
    t.index ["configurable_type", "configurable_id"], name: "index_configs_on_configurable"
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", default: "direct", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_conversations_on_agent_id"
  end

  create_table "custom_apps", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "entrypoint", default: "index.html"
    t.string "icon_emoji"
    t.string "name", null: false
    t.string "path", null: false
    t.string "status", default: "published"
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_custom_apps_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_custom_apps_on_account_id"
    t.index ["agent_id"], name: "index_custom_apps_on_agent_id"
  end

  create_table "custom_tools", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "entrypoint", null: false
    t.string "name", null: false
    t.json "parameter_schema", default: {}
    t.datetime "updated_at", null: false
    t.index ["agent_id", "name"], name: "index_custom_tools_on_agent_id_and_name", unique: true
    t.index ["agent_id"], name: "index_custom_tools_on_agent_id"
  end

  create_table "key_chains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.string "owner_type", null: false
    t.boolean "sandbox_accessible", default: false, null: false
    t.text "secrets"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "name"], name: "index_key_chains_on_owner_type_and_owner_id_and_name", unique: true
  end

  create_table "memories", force: :cascade do |t|
    t.integer "access_count", default: 0, null: false
    t.integer "agent_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "demoted_at"
    t.string "demotion_reason"
    t.binary "embedding"
    t.float "importance", default: 0.6, null: false
    t.datetime "last_accessed_at"
    t.datetime "promoted_at"
    t.integer "promoted_count", default: 0, null: false
    t.string "source", default: "agent", null: false
    t.string "state", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "state", "created_at"], name: "index_memories_on_agent_id_and_state_and_created_at"
    t.index ["agent_id", "state"], name: "index_memories_on_agent_id_and_state"
    t.index ["agent_id"], name: "index_memories_on_agent_id"
  end

  create_table "messages", force: :cascade do |t|
    t.datetime "compacted_at"
    t.text "content"
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.string "tool_call_id"
    t.text "tool_calls"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "participants", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["conversation_id", "user_id"], name: "index_participants_on_conversation_id_and_user_id", unique: true
    t.index ["conversation_id"], name: "index_participants_on_conversation_id"
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "plugin_configs", force: :cascade do |t|
    t.integer "configurable_id", null: false
    t.string "configurable_type", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.integer "plugin_id", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["configurable_type", "configurable_id"], name: "index_plugin_configs_on_configurable"
    t.index ["plugin_id", "configurable_type", "configurable_id", "key"], name: "idx_plugin_configs_unique", unique: true
    t.index ["plugin_id"], name: "index_plugin_configs_on_plugin_id"
  end

  create_table "plugins", force: :cascade do |t|
    t.integer "account_id", null: false
    t.json "config_schema", default: []
    t.datetime "created_at", null: false
    t.text "description"
    t.string "entrypoint"
    t.string "execution", default: "sandbox", null: false
    t.json "mounts", default: []
    t.string "name", null: false
    t.json "packages", default: []
    t.json "permissions", default: {}
    t.string "plugin_type", default: "tool", null: false
    t.json "tools", default: []
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0.0", null: false
    t.index ["account_id", "name"], name: "index_plugins_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_plugins_on_account_id"
  end

  create_table "providers", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "designation", default: "none", null: false
    t.string "model"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "designation"], name: "index_providers_on_account_id_and_designation"
    t.index ["account_id", "name"], name: "index_providers_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_providers_on_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skills", force: :cascade do |t|
    t.integer "account_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_skills_on_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.string "phone_number"
    t.string "role", default: "member", null: false
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_models", "agents"
  add_foreign_key "agent_models", "providers"
  add_foreign_key "agent_plugins", "agents"
  add_foreign_key "agent_plugins", "plugins"
  add_foreign_key "agent_users", "agents"
  add_foreign_key "agent_users", "users"
  add_foreign_key "agents", "accounts"
  add_foreign_key "conversations", "agents"
  add_foreign_key "custom_apps", "accounts"
  add_foreign_key "custom_apps", "agents"
  add_foreign_key "custom_tools", "agents"
  add_foreign_key "memories", "agents"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "participants", "conversations"
  add_foreign_key "participants", "users"
  add_foreign_key "plugin_configs", "plugins"
  add_foreign_key "plugins", "accounts"
  add_foreign_key "providers", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "skills", "accounts"
  add_foreign_key "users", "accounts"
end
