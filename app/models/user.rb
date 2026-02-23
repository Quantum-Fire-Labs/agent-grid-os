class User < ApplicationRecord
  belongs_to :account
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :conversations, through: :participants
  has_many :agent_users, dependent: :destroy
  has_many :agents, through: :agent_users
  has_many :custom_app_users, dependent: :destroy
  has_many :custom_apps, through: :custom_app_users

  enum :role, %w[admin member].index_by(&:itself), default: "member"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
