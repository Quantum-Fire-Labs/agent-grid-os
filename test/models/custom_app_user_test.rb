require "test_helper"

class CustomAppUserTest < ActiveSupport::TestCase
  test "valid for same-account user and app" do
    custom_app_user = CustomAppUser.new(user: users(:one), custom_app: custom_apps(:slideshow))
    assert custom_app_user.valid?
  end

  test "rejects duplicate assignment" do
    existing = custom_app_users(:teammate_slideshow)
    duplicate = CustomAppUser.new(user: existing.user, custom_app: existing.custom_app)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:custom_app_id], "has already been taken"
  end

  test "rejects cross-account assignment" do
    custom_app_user = CustomAppUser.new(user: users(:two), custom_app: custom_apps(:slideshow))
    assert_not custom_app_user.valid?
    assert_includes custom_app_user.errors[:base], "User and app must belong to the same account"
  end

  test "destroying custom app destroys user assignments" do
    assert_difference "CustomAppUser.count", -1 do
      custom_apps(:slideshow).destroy
    end
  end

  test "destroying user destroys app assignments" do
    assert_difference "CustomAppUser.count", -1 do
      users(:teammate).destroy
    end
  end
end
