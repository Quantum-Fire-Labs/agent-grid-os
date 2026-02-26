require "test_helper"

class Agent::Tools::AppDataToolsTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @app = custom_apps(:draft_app)
    @granted_agent = agents(:three)
    @table = "t_#{SecureRandom.hex(4)}"
    @written_apps = []

    @app.create_table(@table, [
      { "name" => "title", "type" => "TEXT" },
      { "name" => "done", "type" => "INTEGER" }
    ])
  end

  teardown do
    [ @app, custom_apps(:slideshow) ].uniq.compact.each do |app|
      begin
        app.drop_table(@table) if @table
      rescue
      end
    end

    @written_apps.each do |app|
      FileUtils.rm_f(app.agent_tools_manifest_path)
      app.remove_instance_variable(:@agent_tools_manifest) if app.instance_variable_defined?(:@agent_tools_manifest)
    end
  end

  test "registry executes app-specific create, find, change, remove, and save tools" do
    write_manifest(@app, tools_manifest(@table))

    create_result = execute("app_draft_app_add_task", "title" => "Buy milk")
    assert_ok(create_result)
    row_id = create_result.dig("result", "id")
    assert_equal "Buy milk", create_result.dig("result", "row", "title")

    find_result = execute("app_draft_app_find_tasks", "done" => 0)
    assert_ok(find_result)
    assert_equal 1, find_result.dig("result", "rows").size

    change_result = execute("app_draft_app_mark_done", "id" => row_id)
    assert_ok(change_result)
    assert_equal 1, change_result.dig("result", "changed")
    assert_equal 1, change_result.dig("result", "row", "done")

    save_create = execute("app_draft_app_save_task", "title" => "Write tests", "done" => 0)
    assert_ok(save_create)
    assert_equal "created", save_create.dig("result", "action")

    save_update = execute("app_draft_app_save_task", "title" => "Write tests", "done" => 1)
    assert_ok(save_update)
    assert_equal "updated", save_update.dig("result", "action")
    assert_equal 1, save_update.dig("result", "row", "done")

    remove_result = execute("app_draft_app_remove_task", "id" => row_id)
    assert_ok(remove_result)
    assert_equal 1, remove_result.dig("result", "removed")
  end

  test "inspect tool returns table schema metadata" do
    write_manifest(@app, tools_manifest(@table))

    result = execute("app_draft_app_inspect")
    assert_ok(result)

    table = result.dig("result", "tables").find { |t| t["name"] == @table }
    assert table
    assert_includes table["columns"].map { |c| c["name"] }, "title"
    assert_includes table["columns"].map { |c| c["name"] }, "done"
  end

  test "workflow runs atomically" do
    write_manifest(@app, tools_manifest(@table))

    result = execute("app_draft_app_fail_workflow", "title" => "bad write")

    refute result["ok"]
    assert_equal "unknown_column", result.dig("error", "code")
    assert_empty @app.query(@table, where: { "title" => "bad write" })
  end

  test "returns structured invalid_arguments error" do
    write_manifest(@app, tools_manifest(@table))

    result = execute("app_draft_app_add_task")

    refute result["ok"]
    assert_equal "invalid_arguments", result.dig("error", "code")
  end

  test "returns row_limit_exceeded for filtered change over limit" do
    write_manifest(@app, tools_manifest(@table))
    @app.insert_row(@table, { "title" => "A", "done" => 0 })
    @app.insert_row(@table, { "title" => "B", "done" => 0 })

    result = execute("app_draft_app_mark_all_done")

    refute result["ok"]
    assert_equal "row_limit_exceeded", result.dig("error", "code")
  end

  test "granted agent receives and executes app-specific tools" do
    app = custom_apps(:slideshow)
    table = "t_#{SecureRandom.hex(4)}"
    app.create_table(table, [ { "name" => "name", "type" => "TEXT" } ])
    write_manifest(app, {
      "version" => 1,
      "tools" => [
        {
          "name" => "add_slide",
          "description" => "Add slide",
          "parameters" => {
            "type" => "object",
            "properties" => { "name" => { "type" => "string" } },
            "required" => [ "name" ]
          },
          "behavior" => { "kind" => "create", "table" => table, "data" => { "name" => { "arg" => "name" } } }
        }
      ]
    })

    tool_names = Agent::ToolRegistry.definitions(agent: @granted_agent).map { |d| d[:function][:name] }
    assert_includes tool_names, "app_slideshow_add_slide"

    result = JSON.parse(Agent::ToolRegistry.execute("app_slideshow_add_slide", { "name" => "Intro" }, agent: @granted_agent))
    assert_ok(result)
    assert_equal "Intro", result.dig("result", "row", "name")
  ensure
    app.drop_table(table) if app && table
  end

  test "missing manifest returns structured error" do
    result = JSON.parse(Agent::ToolRegistry.execute("app_draft_app_add_task", {}, agent: @agent))

    refute result["ok"]
    assert_equal "manifest_missing", result.dig("error", "code")
  end

  private
    def execute(tool_name, arguments = {})
      JSON.parse(Agent::ToolRegistry.execute(tool_name, arguments, agent: @agent))
    end

    def assert_ok(result)
      assert_equal true, result["ok"], "Expected success, got: #{result.inspect}"
    end

    def write_manifest(app, manifest)
      FileUtils.mkdir_p(app.files_path)
      File.write(app.agent_tools_manifest_path, manifest.to_yaml)
      @written_apps << app
    end

    def tools_manifest(table)
      {
        "version" => 1,
        "tools" => [
          {
            "name" => "inspect",
            "description" => "Inspect app data",
            "parameters" => { "type" => "object", "properties" => {}, "required" => [] },
            "behavior" => { "kind" => "inspect" }
          },
          {
            "name" => "add_task",
            "description" => "Add task",
            "parameters" => {
              "type" => "object",
              "properties" => { "title" => { "type" => "string" } },
              "required" => [ "title" ]
            },
            "behavior" => {
              "kind" => "create",
              "table" => table,
              "data" => { "title" => { "arg" => "title" }, "done" => 0 }
            }
          },
          {
            "name" => "find_tasks",
            "description" => "Find tasks",
            "parameters" => {
              "type" => "object",
              "properties" => { "done" => { "type" => "integer" } },
              "required" => [ "done" ]
            },
            "behavior" => {
              "kind" => "find",
              "table" => table,
              "where" => { "done" => { "arg" => "done" } },
              "order" => [ { "column" => "id", "direction" => "ASC" } ]
            }
          },
          {
            "name" => "mark_done",
            "description" => "Mark one task done",
            "parameters" => {
              "type" => "object",
              "properties" => { "id" => { "type" => "integer" } },
              "required" => [ "id" ]
            },
            "behavior" => {
              "kind" => "change",
              "table" => table,
              "id" => { "arg" => "id" },
              "data" => { "done" => 1 }
            }
          },
          {
            "name" => "mark_all_done",
            "description" => "Mark all tasks done",
            "parameters" => { "type" => "object", "properties" => {}, "required" => [] },
            "behavior" => {
              "kind" => "change",
              "table" => table,
              "where" => { "done" => 0 },
              "max_rows" => 1,
              "data" => { "done" => 1 }
            }
          },
          {
            "name" => "remove_task",
            "description" => "Remove a task",
            "parameters" => {
              "type" => "object",
              "properties" => { "id" => { "type" => "integer" } },
              "required" => [ "id" ]
            },
            "behavior" => {
              "kind" => "remove",
              "table" => table,
              "id" => { "arg" => "id" }
            }
          },
          {
            "name" => "save_task",
            "description" => "Create or update a task by title",
            "parameters" => {
              "type" => "object",
              "properties" => {
                "title" => { "type" => "string" },
                "done" => { "type" => "integer" }
              },
              "required" => [ "title", "done" ]
            },
            "behavior" => {
              "kind" => "save",
              "table" => table,
              "match" => { "title" => { "arg" => "title" } },
              "data" => { "title" => { "arg" => "title" }, "done" => { "arg" => "done" } }
            }
          },
          {
            "name" => "fail_workflow",
            "description" => "Fail after writing",
            "parameters" => {
              "type" => "object",
              "properties" => { "title" => { "type" => "string" } },
              "required" => [ "title" ]
            },
            "behavior" => {
              "kind" => "workflow",
              "steps" => [
                {
                  "kind" => "create",
                  "table" => table,
                  "data" => { "title" => { "arg" => "title" }, "done" => 0 }
                },
                {
                  "kind" => "change",
                  "table" => table,
                  "where" => { "title" => { "arg" => "title" } },
                  "max_rows" => 1,
                  "data" => { "missing_column" => 1 }
                }
              ]
            }
          }
        ]
      }
    end
end
