require "test_helper"

class CustomAppAgentAccessTest < ActiveSupport::TestCase
  test "valid access for same-account agent and app" do
    access = CustomAppAgentAccess.new(agent: agents(:three), custom_app: custom_apps(:draft_app))
    assert access.valid?
  end

  test "rejects duplicate access" do
    access = custom_app_agent_accesses(:nova_slideshow)
    duplicate = CustomAppAgentAccess.new(agent: access.agent, custom_app: access.custom_app)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:custom_app_id], "has already been taken"
  end

  test "rejects cross-account access" do
    access = CustomAppAgentAccess.new(agent: agents(:three), custom_app: custom_apps(:other_account_app))
    assert_not access.valid?
    assert_includes access.errors[:base], "Agent and app must belong to the same account"
  end

  test "agent accessible_apps includes own and granted apps" do
    agent = agents(:three)
    assert_includes agent.accessible_apps, custom_apps(:slideshow)
  end

  test "agent accessible_apps does not include ungranted apps" do
    agent = agents(:three)
    assert_not_includes agent.accessible_apps, custom_apps(:draft_app)
  end

  test "destroying agent destroys accesses" do
    agent = agents(:three)
    assert_difference "CustomAppAgentAccess.count", -1 do
      agent.destroy
    end
  end

  test "destroying custom app destroys accesses" do
    app = custom_apps(:slideshow)
    assert_difference "CustomAppAgentAccess.count", -1 do
      app.destroy
    end
  end
end
