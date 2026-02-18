class PluginConfig < ApplicationRecord
  belongs_to :plugin
  belongs_to :configurable, polymorphic: true

  encrypts :value

  validates :key, presence: true,
    uniqueness: { scope: [ :plugin_id, :configurable_type, :configurable_id ] }
end
