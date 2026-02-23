class CustomAppUser < ApplicationRecord
  belongs_to :custom_app
  belongs_to :user

  validates :custom_app_id, uniqueness: { scope: :user_id }
  validate :same_account

  private
    def same_account
      return if user.blank? || custom_app.blank?
      errors.add(:base, "User and app must belong to the same account") unless user.account_id == custom_app.account_id
    end
end
