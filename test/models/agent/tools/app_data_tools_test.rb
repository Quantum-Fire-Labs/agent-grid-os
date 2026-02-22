require "test_helper"

class Agent::Tools::AppDataToolsTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @app = custom_apps(:draft_app)
    @table = "t_#{SecureRandom.hex(6)}"
    @app.create_table(@table, [
      { "name" => "title", "type" => "TEXT" },
      { "name" => "done", "type" => "INTEGER" }
    ])
    @app.insert_row(@table, { "title" => "Buy milk", "done" => 0 })
    @app.insert_row(@table, { "title" => "Write tests", "done" => 1 })
  end

  # --- list_app_tables ---

  test "list_app_tables returns table names" do
    result = call_tool(Agent::Tools::ListAppTables, "app" => "draft-app")

    assert_match /Tables in 'draft-app'/, result
    assert_match @table, result
  end

  test "list_app_tables with unknown app" do
    result = call_tool(Agent::Tools::ListAppTables, "app" => "nonexistent")

    assert_match /Error.*no app named 'nonexistent'/, result
  end

  # --- query_app_data ---

  test "query_app_data returns all rows" do
    result = call_tool(Agent::Tools::QueryAppData, "app" => "draft-app", "table" => @table)

    assert_match /2 row/, result
    assert_match /Buy milk/, result
    assert_match /Write tests/, result
  end

  test "query_app_data with where filter" do
    result = call_tool(Agent::Tools::QueryAppData,
      "app" => "draft-app", "table" => @table, "where" => { "done" => 1 })

    assert_match /1 row/, result
    assert_match /Write tests/, result
    assert_no_match(/Buy milk/, result)
  end

  test "query_app_data with limit" do
    result = call_tool(Agent::Tools::QueryAppData,
      "app" => "draft-app", "table" => @table, "limit" => 1)

    assert_match /1 row/, result
  end

  test "query_app_data with no results" do
    result = call_tool(Agent::Tools::QueryAppData,
      "app" => "draft-app", "table" => @table, "where" => { "title" => "nope" })

    assert_match /No rows found/, result
  end

  test "query_app_data with unknown app" do
    result = call_tool(Agent::Tools::QueryAppData, "app" => "nope", "table" => @table)

    assert_match /Error.*no app named/, result
  end

  # --- insert_app_data ---

  test "insert_app_data adds a row" do
    result = call_tool(Agent::Tools::InsertAppData,
      "app" => "draft-app", "table" => @table, "data" => { "title" => "New task", "done" => 0 })

    assert_match /Inserted row with id \d+/, result
    assert_includes @app.query(@table).map { |r| r["title"] }, "New task"
  end

  test "insert_app_data with unknown app" do
    result = call_tool(Agent::Tools::InsertAppData,
      "app" => "nope", "table" => @table, "data" => { "title" => "x" })

    assert_match /Error.*no app named/, result
  end

  # --- update_app_data ---

  test "update_app_data modifies a row" do
    row_id = @app.query(@table, where: { "title" => "Buy milk" }).first["id"]

    result = call_tool(Agent::Tools::UpdateAppData,
      "app" => "draft-app", "table" => @table, "row_id" => row_id, "data" => { "done" => 1 })

    assert_match /Updated 1 row/, result
    assert_equal 1, @app.get_row(@table, row_id)["done"]
  end

  test "update_app_data with nonexistent row" do
    result = call_tool(Agent::Tools::UpdateAppData,
      "app" => "draft-app", "table" => @table, "row_id" => 99999, "data" => { "done" => 1 })

    assert_match /No row with id 99999/, result
  end

  test "update_app_data with unknown app" do
    result = call_tool(Agent::Tools::UpdateAppData,
      "app" => "nope", "table" => @table, "row_id" => 1, "data" => { "done" => 1 })

    assert_match /Error.*no app named/, result
  end

  # --- delete_app_data ---

  test "delete_app_data removes a row" do
    row_id = @app.query(@table, where: { "title" => "Buy milk" }).first["id"]

    result = call_tool(Agent::Tools::DeleteAppData,
      "app" => "draft-app", "table" => @table, "row_id" => row_id)

    assert_match /Deleted row #{row_id}/, result
    assert_nil @app.get_row(@table, row_id)
  end

  test "delete_app_data with nonexistent row" do
    result = call_tool(Agent::Tools::DeleteAppData,
      "app" => "draft-app", "table" => @table, "row_id" => 99999)

    assert_match /No row with id 99999/, result
  end

  test "delete_app_data with unknown app" do
    result = call_tool(Agent::Tools::DeleteAppData,
      "app" => "nope", "table" => @table, "row_id" => 1)

    assert_match /Error.*no app named/, result
  end

  # --- tool definitions ---

  test "all tools have valid definitions" do
    [
      Agent::Tools::ListAppTables,
      Agent::Tools::QueryAppData,
      Agent::Tools::InsertAppData,
      Agent::Tools::UpdateAppData,
      Agent::Tools::DeleteAppData
    ].each do |tool_class|
      defn = tool_class.definition
      assert_equal "function", defn[:type]
      assert defn[:function][:name].present?
      assert defn[:function][:description].present?
      assert defn[:function][:parameters].present?
    end
  end

  private
    def call_tool(klass, arguments)
      klass.new(agent: @agent, arguments: arguments).call
    end
end
