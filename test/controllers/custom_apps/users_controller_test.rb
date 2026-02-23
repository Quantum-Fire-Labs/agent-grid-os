require "test_helper"

class CustomApps::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:teammate)
    @custom_app = custom_apps(:slideshow)
  end

  test "admin can add a user to an app" do
    sign_in_as(@admin)
    assert_difference "CustomAppUser.count", 1 do
      post custom_app_users_path(@custom_app), params: { user_id: @admin.id }
    end
    assert_redirected_to custom_app_settings_path(@custom_app)
  end

  test "admin can remove a user from an app" do
    sign_in_as(@admin)
    custom_app_user = custom_app_users(:teammate_slideshow)
    assert_difference "CustomAppUser.count", -1 do
      delete custom_app_user_path(@custom_app, custom_app_user)
    end
    assert_redirected_to custom_app_settings_path(@custom_app)
  end

  test "rejects duplicate assignment" do
    sign_in_as(@admin)
    assert_no_difference "CustomAppUser.count" do
      post custom_app_users_path(@custom_app), params: { user_id: @member.id }
    end
    assert_response :unprocessable_entity
  end

  test "member cannot add users" do
    sign_in_as(@member)
    assert_no_difference "CustomAppUser.count" do
      post custom_app_users_path(@custom_app), params: { user_id: @admin.id }
    end
    assert_redirected_to root_path
  end

  test "member cannot remove users" do
    sign_in_as(@member)
    custom_app_user = custom_app_users(:teammate_slideshow)
    assert_no_difference "CustomAppUser.count" do
      delete custom_app_user_path(@custom_app, custom_app_user)
    end
    assert_redirected_to root_path
  end
end
