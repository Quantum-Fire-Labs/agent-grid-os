class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :agents, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :custom_apps, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :plugins, dependent: :destroy
  has_many :plugin_configs, as: :configurable, dependent: :destroy
  has_many :providers, dependent: :destroy
  has_many :key_chains, as: :owner, dependent: :destroy
  has_many :configs, as: :configurable, dependent: :destroy
  has_many :scheduled_actions, dependent: :destroy

  validates :name, presence: true
end
