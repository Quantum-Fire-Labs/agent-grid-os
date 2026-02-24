require "test_helper"

class Agent::BrainTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @chat = chats(:one)
    @brain = Agent::Brain.new(@agent, @chat)
  end

  test "think delegates to provider plugin when provider_mode is true" do
    fake_class = Class.new do
      define_method(:initialize) { |agent:, plugin:| }
      define_method(:chat) do |messages:, model:, chat:, &on_token|
        Providers::Response.new(content: "from provider plugin", tool_calls: [], usage: {})
      end
    end

    # Override provider_entrypoint_class on the exact object Brain will find
    plugin = @agent.plugins.detect { |p| p.provider_mode?(@agent) }
    assert plugin, "Expected agent to have a provider-mode plugin"
    plugin.define_singleton_method(:provider_entrypoint_class) { fake_class }

    response = @brain.send(:think)
    assert_equal "from provider plugin", response.content
    assert_not response.tool_calls?
  end

  test "think falls through to normal provider when plugin MODE is tool" do
    plugin_configs(:claude_code_mode_provider).update!(value: "tool")

    plugin = plugins(:claude_code)
    assert_not plugin.provider_mode?(@agent)
  end
end
