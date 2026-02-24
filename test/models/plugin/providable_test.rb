require "test_helper"

class Plugin::ProvidableTest < ActiveSupport::TestCase
  test "provider? returns true when provider_config is present" do
    plugin = plugins(:claude_code)
    assert plugin.provider?
  end

  test "provider? returns false when provider_config is nil" do
    plugin = plugins(:simple_tool)
    assert_not plugin.provider?
  end

  test "provider_mode? returns true when plugin has provider config and MODE is provider" do
    plugin = plugins(:claude_code)
    agent = agents(:one)
    assert plugin.provider_mode?(agent)
  end

  test "provider_mode? returns false when MODE is tool" do
    plugin = plugins(:claude_code)
    agent = agents(:one)

    # Override the MODE config to "tool"
    config = plugin_configs(:claude_code_mode_provider)
    config.update!(value: "tool")

    assert_not plugin.provider_mode?(agent)
  end

  test "provider_mode? returns false when no MODE config exists" do
    plugin = plugins(:claude_code)
    agent = agents(:three) # No plugin config for this agent
    assert_not plugin.provider_mode?(agent)
  end

  test "provider_mode? returns false when plugin has no provider_config" do
    plugin = plugins(:simple_tool)
    agent = agents(:one)
    assert_not plugin.provider_mode?(agent)
  end

  test "provider_entrypoint_class returns nil when not a provider" do
    plugin = plugins(:simple_tool)
    assert_nil plugin.provider_entrypoint_class
  end
end
