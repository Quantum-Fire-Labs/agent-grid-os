class Memory < ApplicationRecord
  belongs_to :agent

  enum :state, %w[ active dormant ].index_by(&:itself), default: "active"

  validates :content, presence: true

  scope :with_embedding, -> { where.not(embedding: nil) }
  scope :recent, ->(days) { where(created_at: days.days.ago..) }

  def embedding_vector
    embedding&.unpack("f*")
  end

  def embedding_vector=(vec)
    self.embedding = vec&.pack("f*")
  end

  def demote(reason:)
    update!(
      state: "dormant",
      embedding: nil,
      demoted_at: Time.current,
      demotion_reason: reason
    )
  end

  def promote(vec)
    update!(
      state: "active",
      embedding: vec&.pack("f*"),
      promoted_at: Time.current,
      promoted_count: promoted_count + 1
    )
  end

  def track_access!
    update_columns(access_count: access_count + 1, last_accessed_at: Time.current)
  end
end
