require "test_helper"

class CustomApps::TablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @custom_app = custom_apps(:slideshow)
  end

  test "index lists tables" do
    get custom_app_tables_path(@custom_app), as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json["tables"]
  end

  test "create table" do
    post custom_app_tables_path(@custom_app),
      params: { name: "slides", columns: [ { name: "title", type: "TEXT" }, { name: "order_num", type: "INTEGER" } ] },
      as: :json
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "slides", json["table"]
  end

  test "create table requires name" do
    post custom_app_tables_path(@custom_app),
      params: { columns: [ { name: "title", type: "TEXT" } ] },
      as: :json
    assert_response :unprocessable_entity
  end

  test "destroy table" do
    @custom_app.create_table("to_drop", [ { "name" => "col", "type" => "TEXT" } ])
    delete custom_app_table_path(@custom_app, "to_drop"), as: :json
    assert_response :no_content
  end
end
