require "test_helper"

class Agent::ToolRegistryTest < ActiveSupport::TestCase
  test "definitions include data tools when agent has own apps" do
    agent = agents(:one) # owns slideshow and draft_app
    names = tool_names(agent)

    assert_includes names, "list_app_tables"
    assert_includes names, "query_app_data"
    assert_includes names, "insert_app_data"
    assert_includes names, "update_app_data"
    assert_includes names, "delete_app_data"
  end

  test "definitions include data tools when agent has granted apps" do
    agent = agents(:three) # granted access to slideshow
    names = tool_names(agent)

    assert_includes names, "list_app_tables"
    assert_includes names, "query_app_data"
  end

  test "definitions exclude data tools when agent has no accessible apps" do
    agent = Agent.create!(name: "Empty", account: accounts(:one))
    names = tool_names(agent)

    assert_not_includes names, "list_app_tables"
    assert_not_includes names, "query_app_data"
  end

  test "definitions exclude workspace tools for non-workspace agent" do
    agent = agents(:three)
    names = tool_names(agent)

    assert_not_includes names, "exec"
    assert_not_includes names, "register_app"
  end

  private
    def tool_names(agent)
      Agent::ToolRegistry.definitions(agent: agent).map { |d| d[:function][:name] }
    end
end
