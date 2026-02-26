require "test_helper"

load Rails.root.join("lib/plugins/missionbase/missionbase.rb")

class MissionbaseTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  class FakeHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :requests

    def initialize(responses)
      @responses = responses.dup
      @requests = []
    end

    def request(request)
      @requests << request
      @responses.shift || FakeResponse.new("500", '{"error":{"message":"missing fake response"}}')
    end
  end

  setup do
    @agent = agents(:one)
    @plugin = @agent.account.plugins.create!(
      name: "missionbase",
      plugin_type: "tool",
      execution: "platform",
      entrypoint: "missionbase.rb",
      tools: [ { "name" => "missionbase_list_teams", "description" => "List teams", "parameters" => { "type" => "object", "properties" => {} } } ],
      config_schema: [
        { "key" => "MISSIONBASE_API_KEY", "type" => "secret", "scope" => "agent" }
      ]
    )
    @plugin.plugin_configs.create!(configurable: @agent, key: "MISSIONBASE_API_KEY", value: "test-key")
  end

  test "list teams sends bearer auth and parses json" do
    fake_http = FakeHttp.new([ FakeResponse.new("200", '{"teams":[{"id":1,"name":"Ops"}]}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_list_teams", {})

      assert_includes output, "Found 1 teams"
      assert_includes output, "[ID: 1]"
      request = fake_http.requests.first
      assert_equal "Bearer test-key", request["Authorization"]
      assert_equal "application/json", request["Accept"]
      assert_equal "/api/v1/teams", request.path
    end
  end

  test "assigned tasks encodes query params" do
    fake_http = FakeHttp.new([ FakeResponse.new("200", '{"tasks":[],"meta":{"total":0}}') ])

    with_http_stub(fake_http) do
      Missionbase.new(agent: @agent).call("missionbase_list_tasks_assigned_to_current_user", {
        "date" => "2026-02-24",
        "include_overdue" => false
      })

      assert_includes fake_http.requests.first.path, "/api/v1/tasks/assigned?"
      assert_includes fake_http.requests.first.path, "include_overdue=false"
      assert_includes fake_http.requests.first.path, "date=2026-02-24"
    end
  end

  test "missing agent api key returns setup error" do
    @plugin.plugin_configs.where(configurable: @agent, key: "MISSIONBASE_API_KEY").delete_all

    output = Missionbase.new(agent: @agent).call("missionbase_list_teams", {})

    assert_includes output, "MISSIONBASE_API_KEY is not configured for this agent"
  end

  test "non-2xx response returns missionbase api error" do
    fake_http = FakeHttp.new([ FakeResponse.new("403", '{"error":{"message":"Insufficient permissions"}}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_list_teams", {})

      assert_includes output, "Missionbase API error"
      assert_includes output, "HTTP 403"
      assert_includes output, "Insufficient permissions"
    end
  end

  test "assign task auto-fetches acting user id for personal api key" do
    fake_http = FakeHttp.new([
      FakeResponse.new("200", '{"user":{"id":42}}'),
      FakeResponse.new("201", '{"assignment":{"task_id":3,"user":{"id":9}}}')
    ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_assign_user_to_task", {
        "task_id" => 3,
        "user_id" => 9
      })

      assert_includes output, "Successfully assigned"
      assert_equal "/api/v1/users/me", fake_http.requests.first.path

      assignment_request = fake_http.requests.second
      assert_equal "/api/v1/tasks/3/assignments", assignment_request.path
      parsed_body = JSON.parse(assignment_request.body)
      assert_equal 42, parsed_body["acting_as_user_id"]
      assert_equal 9, parsed_body["user_id"]
    end
  end

  test "create task treats assign_to_user_id zero as omitted when assigning to current user" do
    fake_http = FakeHttp.new([ FakeResponse.new("201", '{"task":{"id":123}}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_create_task", {
        "title" => "Test task from Dash",
        "team_id" => 2,
        "box_id" => 121,
        "description" => "Created via Missionbase integration test.",
        "do_on" => "2026-02-24",
        "deadline" => "2026-02-24",
        "assign_to_current_user" => true,
        "assign_to_user_id" => 0
      })

      assert_includes output, "Successfully created task"
      request = fake_http.requests.first
      assert_equal "/api/v1/tasks", request.path
      body = JSON.parse(request.body)
      assert_equal true, body["assign_to_current_user"]
      assert_equal 121, body["box_id"]
      assert_not body.key?("assign_to_user_id")
    end
  end

  test "create task treats string zero assign_to_user_id as omitted" do
    fake_http = FakeHttp.new([ FakeResponse.new("201", '{"task":{"id":123}}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_create_task", {
        "title" => "Test task from Dash",
        "team_id" => 2,
        "assign_to_current_user" => true,
        "assign_to_user_id" => "0"
      })

      assert_includes output, "Successfully created task"
      body = JSON.parse(fake_http.requests.first.body)
      assert_not body.key?("assign_to_user_id")
    end
  end

  test "create task drops explicit assign_to_user_id when assign_to_current_user is true" do
    fake_http = FakeHttp.new([ FakeResponse.new("201", '{"task":{"id":123}}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_create_task", {
        "title" => "Test task from Dash",
        "team_id" => 2,
        "assign_to_current_user" => true,
        "assign_to_user_id" => 9
      })

      assert_includes output, "Successfully created task"
      body = JSON.parse(fake_http.requests.first.body)
      assert_equal true, body["assign_to_current_user"]
      assert_not body.key?("assign_to_user_id")
    end
  end

  test "update task forwards box_id to tasks update endpoint" do
    fake_http = FakeHttp.new([ FakeResponse.new("200", '{"task":{"id":123,"title":"Moved task"}}') ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_update_task", {
        "id" => 123,
        "box_id" => 121
      })

      assert_includes output, "Successfully updated task"
      request = fake_http.requests.first
      assert_equal "/api/v1/tasks/123", request.path
      assert_equal "PATCH", request.method
      body = JSON.parse(request.body)
      assert_equal 121, body["box_id"]
      assert_equal({ "box_id" => 121 }, body)
    end
  end

  test "add comment to task posts directly to task comments endpoint" do
    fake_http = FakeHttp.new([
      FakeResponse.new("201", '{"comment":{"id":55,"feed_id":777}}')
    ])

    with_http_stub(fake_http) do
      output = Missionbase.new(agent: @agent).call("missionbase_add_comment_to_task", {
        "task_id" => 1733,
        "comment" => "Looks good"
      })

      assert_includes output, "Successfully added comment"
      assert_equal "/api/v1/tasks/1733/comments", fake_http.requests[0].path
      assert_equal({ "comment" => "Looks good" }, JSON.parse(fake_http.requests[0].body))
    end
  end

  test "conversation comment tool with task_id recommends task helper tool" do
    output = Missionbase.new(agent: @agent).call("missionbase_add_comment_to_conversation", {
      "task_id" => 1733,
      "comment" => "Looks good"
    })

    assert_includes output, "Use missionbase_add_comment_to_task"
  end

  test "tool registry executes missionbase platform plugin" do
    agent = accounts(:two).agents.create!(name: "Missionbase Runner", network_mode: "full")
    installed = Plugin.install_from(
      account: agent.account,
      source_path: Rails.root.join("lib/plugins/missionbase").to_s
    )
    installed.plugin_configs.create!(configurable: agent, key: "MISSIONBASE_API_KEY", value: "test-key")
    agent.agent_plugins.create!(plugin: installed)

    fake_http = FakeHttp.new([ FakeResponse.new("200", '{"teams":[{"id":1}]}') ])

    with_http_stub(fake_http) do
      output = Agent::ToolRegistry.execute("missionbase_list_teams", {}, agent: agent)
      assert_includes output, "Found 1 teams"
    end
  ensure
    installed&.destroy
  end

  test "tool registry definitions include namespaced mcp-style missionbase tools" do
    agent = accounts(:two).agents.create!(name: "Missionbase Catalog Agent", network_mode: "full")
    installed = Plugin.install_from(
      account: agent.account,
      source_path: Rails.root.join("lib/plugins/missionbase").to_s
    )
    agent.agent_plugins.create!(plugin: installed)

    names = Agent::ToolRegistry.definitions(agent: agent).map { |d| d[:function][:name] }
    assert_includes names, "missionbase_list_tasks_assigned_to_current_user"
    assert_includes names, "missionbase_get_current_user"
    assert_includes names, "missionbase_add_comment_to_task"
    assert_not_includes names, "missionbase_list_tasks_assigned"
  ensure
    installed&.destroy
  end

  private
    def with_http_stub(fake_http)
      singleton = class << Net::HTTP
        self
      end
      singleton.alias_method :__missionbase_test_original_new, :new
      singleton.define_method(:new) { |_host, _port| fake_http }
      yield
    ensure
      singleton.alias_method :new, :__missionbase_test_original_new
      singleton.remove_method :__missionbase_test_original_new
    end
end
