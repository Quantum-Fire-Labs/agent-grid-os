class Provider < ApplicationRecord
  belongs_to :account
  has_many :agent_models, dependent: :destroy

  enum :designation, %w[default fallback none].index_by(&:itself), default: "none", prefix: true

  validates :name, presence: true, uniqueness: { scope: :account_id }

  before_save :demote_existing_default, if: :designation_default?

  attr_accessor :current_agent

  CLIENTS = {
    "openrouter" => Providers::OpenRouter,
    "openai" => Providers::OpenAi,
    "chatgpt" => Providers::ChatGpt
  }.freeze

  def client
    client_class.new(self)
  end

  def display_name
    client_class.display_name
  end

  def key_chain(agent: current_agent)
    if agent
      KeyChain.find_by(owner: agent, name: name) ||
        KeyChain.find_by(owner: account, name: name)
    else
      KeyChain.find_by(owner: account, name: name)
    end
  end

  def connected?(agent: current_agent)
    client.connected?(agent: agent)
  end

  private
    def demote_existing_default
      Provider.where(account: account)
              .where(designation: :default)
              .where.not(id: id)
              .update_all(designation: :fallback)
    end

    def client_class
      CLIENTS.fetch(name) { raise Providers::Error, "Unknown provider: #{name}" }
    end
end
