require "test_helper"

class Agent::BrainTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @chat = chats(:one)
    @brain = Agent::Brain.new(@agent, @chat)
  end
end
