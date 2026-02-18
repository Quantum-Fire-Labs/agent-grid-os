require "test_helper"

class CustomApps::RowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @custom_app = custom_apps(:slideshow)
    @custom_app.create_table("items", [ { "name" => "title", "type" => "TEXT" }, { "name" => "value", "type" => "INTEGER" } ])
  end

  test "create row" do
    post custom_app_table_rows_path(@custom_app, "items"),
      params: { data: { title: "Hello", value: 42 } },
      as: :json
    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
  end

  test "index rows" do
    @custom_app.insert_row("items", { "title" => "Row1", "value" => 1 })
    get custom_app_table_rows_path(@custom_app, "items"), as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["rows"].size >= 1
  end

  test "show row" do
    row_id = @custom_app.insert_row("items", { "title" => "Test", "value" => 99 })
    get custom_app_table_row_path(@custom_app, "items", row_id), as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Test", json["row"]["title"]
  end

  test "update row" do
    row_id = @custom_app.insert_row("items", { "title" => "Old", "value" => 1 })
    patch custom_app_table_row_path(@custom_app, "items", row_id),
      params: { data: { title: "New" } },
      as: :json
    assert_response :success
  end

  test "delete row" do
    row_id = @custom_app.insert_row("items", { "title" => "ToDelete", "value" => 0 })
    delete custom_app_table_row_path(@custom_app, "items", row_id), as: :json
    assert_response :no_content
  end

  test "show nonexistent row returns 404" do
    get custom_app_table_row_path(@custom_app, "items", 99999), as: :json
    assert_response :not_found
  end
end
