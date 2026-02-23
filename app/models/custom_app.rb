class CustomApp < ApplicationRecord
  include Servable
  include Storable

  belongs_to :agent
  belongs_to :account
  has_many :custom_app_agent_accesses, dependent: :destroy
  has_many :custom_app_users, dependent: :destroy
  has_many :users, through: :custom_app_users
  has_one_attached :icon_image

  before_validation :set_account_from_agent, on: :create
  before_validation :set_name_from_slug, on: :create
  before_validation :set_path_from_slug, on: :create
  after_create :create_files_directory
  after_create_commit :recreate_creator_workspace
  after_destroy_commit :recreate_creator_workspace
  after_destroy_commit :cleanup_storage

  enum :status, %w[ draft published disabled ].index_by(&:itself)

  validates :slug, presence: true,
    format: { with: /\A[a-z][a-z0-9\-]{0,49}\z/, message: "must start with a letter and contain only lowercase letters, numbers, and hyphens" },
    uniqueness: { scope: :account_id }
  validates :name, presence: true

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

    def set_name_from_slug
      self.name = slug.titleize if name.blank? && slug.present?
    end

    def set_path_from_slug
      self.path ||= "apps/#{slug}" if slug.present?
    end

    def create_files_directory
      FileUtils.mkdir_p(files_path)
    end

    def recreate_creator_workspace
      return unless agent.workspace_enabled?

      workspace = Agent::Workspace.new(agent)
      return unless workspace.exists?

      workspace.destroy
      workspace.start
    end

    def cleanup_storage
      CleanupAppStorageJob.perform_later(storage_path.to_s)
    end
end
