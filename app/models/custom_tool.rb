class CustomTool < ApplicationRecord
  belongs_to :agent

  MAX_PER_AGENT = 20
  NAME_FORMAT = /\A[a-z][a-z0-9_]{0,49}\z/

  validates :name, presence: true, format: { with: NAME_FORMAT }, uniqueness: { scope: :agent_id }
  validates :description, presence: true
  validates :entrypoint, presence: true
  validate :enforce_limit, on: :create

  def tool_name
    "custom_#{name}"
  end

  def definition
    {
      type: "function",
      function: {
        name: tool_name,
        description: description,
        parameters: parameter_schema.presence || { type: "object", properties: {}, required: [] }
      }
    }
  end

  private

  def enforce_limit
    if agent && agent.custom_tools.count >= MAX_PER_AGENT
      errors.add(:base, "Maximum of #{MAX_PER_AGENT} custom tools per agent")
    end
  end
end
