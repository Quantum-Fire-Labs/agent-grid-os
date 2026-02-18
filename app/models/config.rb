class Config < ApplicationRecord
  belongs_to :configurable, polymorphic: true

  encrypts :value

  validates :key, presence: true, uniqueness: { scope: %i[configurable_type configurable_id] }
end
