class Agent < ApplicationRecord
  include Resettable
  include Cloneable

  belongs_to :account
  has_many :agent_users, dependent: :destroy
  has_many :users, through: :agent_users
  has_many :participants, as: :participatable, dependent: :destroy
  has_many :chats, through: :participants
  has_many :memories, dependent: :destroy
  has_many :agent_models, dependent: :destroy
  has_many :providers, through: :agent_models
  has_many :custom_tools, dependent: :destroy
  has_many :agent_skills, dependent: :destroy
  has_many :skills, through: :agent_skills
  has_many :custom_apps, dependent: :destroy
  has_many :agent_plugins, dependent: :destroy
  has_many :plugins, through: :agent_plugins
  has_many :custom_app_agent_accesses, dependent: :destroy
  has_many :granted_apps, through: :custom_app_agent_accesses, source: :custom_app
  has_many :plugin_configs, as: :configurable, dependent: :destroy
  has_many :key_chains, as: :owner, dependent: :destroy
  has_many :configs, as: :configurable, dependent: :destroy

  enum :status, %w[ running asleep exiled ].index_by(&:itself), default: "asleep"
  enum :network_mode, %w[ none allowed allowed_plus_skills full ].index_by(&:itself), default: "none", prefix: true

  validates :name, presence: true, uniqueness: { scope: :account_id }

  after_create :associate_account_providers

  def resolve_provider(designation: "default")
    resolve_model(designation: designation)&.provider
  end

  def resolve_model(designation: "default")
    agent_model = agent_models.find_by(designation: designation)

    if agent_model
      agent_model.provider.current_agent = self
      return agent_model
    end

    # Fall back to account-level provider
    provider = account.providers.find_by(designation: designation)
    if provider
      provider.current_agent = self

      if !provider.connected? && designation == "default"
        return resolve_model(designation: "fallback")
      end

      # Return a read-only AgentModel-like object for the account fallback
      agent_models.new(provider: provider, model: provider.model, designation: designation)
    elsif designation == "default"
      resolve_model(designation: "fallback")
    end
  end

  def accessible_apps
    CustomApp.where(agent_id: id)
      .or(CustomApp.where(id: CustomAppAgentAccess.where(agent_id: id).select(:custom_app_id)))
  end

  def find_or_create_direct_chat(user)
    existing = account.chats
      .joins(:participants)
      .group("chats.id")
      .having("COUNT(*) = 2")
      .having(
        "SUM(CASE WHEN participants.participatable_type = ? AND participants.participatable_id = ? THEN 1 ELSE 0 END) = 1",
        "User",
        user.id
      )
      .having(
        "SUM(CASE WHEN participants.participatable_type = ? AND participants.participatable_id = ? THEN 1 ELSE 0 END) = 1",
        "Agent",
        id
      )
      .first
    return existing if existing

    account.chats.create!.tap do |chat|
      chat.participants.create!(participatable: user)
      chat.participants.create!(participatable: self)
    end
  end

  private
    def associate_account_providers
      account.providers.where.not(designation: :none).find_each do |provider|
        agent_models.create!(
          provider: provider,
          model: provider.model,
          designation: provider.designation
        )
      end
    end
end
