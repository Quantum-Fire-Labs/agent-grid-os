class Agent::Tools::Base
  attr_reader :agent, :arguments, :context

  def initialize(agent:, arguments:, context: {})
    @agent = agent
    @arguments = arguments
    @context = context
  end

  def call
    raise NotImplementedError
  end

  def self.definition
    raise NotImplementedError
  end
end
