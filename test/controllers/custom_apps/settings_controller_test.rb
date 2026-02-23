require "test_helper"

class CustomApps::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:teammate)
    @custom_app = custom_apps(:slideshow)
  end

  test "admin can view settings" do
    sign_in_as(@admin)
    get custom_app_settings_path(@custom_app)
    assert_response :success
  end

  test "member cannot view settings" do
    sign_in_as(@member)
    get custom_app_settings_path(@custom_app)
    assert_redirected_to root_path
  end

  test "scoped to current account" do
    sign_in_as(@admin)
    other_app = custom_apps(:other_account_app)
    get custom_app_settings_path(other_app)
    assert_response :not_found
  end
end
