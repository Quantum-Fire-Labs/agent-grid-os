class KeyChain < ApplicationRecord
  belongs_to :owner, polymorphic: true

  attribute :secrets, :json
  encrypts :secrets

  validates :name, presence: true, uniqueness: { scope: [ :owner_type, :owner_id ] }

  def api_key          = secrets&.dig("api_key")
  def access_token     = secrets&.dig("access_token")
  def refresh_token    = secrets&.dig("refresh_token")
  def oauth_account_id = secrets&.dig("oauth_account_id")
end
