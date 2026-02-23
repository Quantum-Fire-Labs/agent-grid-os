require "test_helper"

class CustomAppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @custom_app = custom_apps(:slideshow)
  end

  test "index shows published apps" do
    get custom_apps_path
    assert_response :success
    assert_select ".app-card-name", text: "Slideshow"
  end

  test "index does not show draft apps" do
    get custom_apps_path
    assert_response :success
    assert_select ".app-card-name", text: "Draft App", count: 0
  end

  test "index does not show apps from other accounts" do
    get custom_apps_path
    assert_response :success
    assert_select ".app-card-name", text: "Other App", count: 0
  end

  test "show renders app" do
    get custom_app_path(@custom_app)
    assert_response :success
  end

  test "show uses custom_app layout" do
    get custom_app_path(@custom_app)
    assert_response :success
    assert_select "script[src='/agentgridos_app_sdk.js']"
  end

  test "show returns 404 for other account app" do
    get custom_app_path(custom_apps(:other_account_app))
    assert_response :not_found
  end

  test "show returns 404 for draft app" do
    get custom_app_path(custom_apps(:draft_app))
    assert_response :not_found
  end

  test "asset returns 404 for directory traversal" do
    get custom_app_asset_path(@custom_app, path: "../../../etc/passwd")
    assert_response :not_found
  end

  test "requires authentication" do
    sign_out
    get custom_apps_path
    assert_response :redirect
  end
end
