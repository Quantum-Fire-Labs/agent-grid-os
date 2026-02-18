class CustomApp < ApplicationRecord
  include Servable
  include Storable

  belongs_to :agent
  belongs_to :account

  before_validation :set_account_from_agent, on: :create
  has_one_attached :icon_image

  enum :status, %w[ draft published disabled ].index_by(&:itself)

  validates :name, presence: true,
    format: { with: /\A[a-z][a-z0-9\-]{0,49}\z/, message: "must start with a letter and contain only lowercase letters, numbers, and hyphens" },
    uniqueness: { scope: :account_id }
  validates :path, presence: true

  def icon_display
    if icon_image.attached?
      :image
    elsif icon_emoji.present?
      :emoji
    else
      :initial
    end
  end

  private

    def set_account_from_agent
      self.account ||= agent&.account
    end
end
