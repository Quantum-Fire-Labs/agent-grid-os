require "test_helper"

class Settings::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "index renders users list" do
    get settings_users_path
    assert_response :success
    assert_select ".user-list"
  end

  test "show renders user detail" do
    get settings_user_path(users(:teammate))
    assert_response :success
    assert_select ".user-profile-name", /Alex/
  end

  test "new renders form" do
    get new_settings_user_path
    assert_response :success
    assert_select "form"
  end

  test "create adds user to account" do
    assert_difference "Current.account.users.count", 1 do
      post settings_users_path, params: { user: {
        first_name: "New", last_name: "User",
        email_address: "new@example.com",
        password: "password123", password_confirmation: "password123"
      } }
    end

    user = User.find_by(email_address: "new@example.com")
    assert_redirected_to settings_user_path(user)
    assert_equal accounts(:one), user.account
  end

  test "create with invalid data renders form" do
    assert_no_difference "User.count" do
      post settings_users_path, params: { user: {
        first_name: "", last_name: "",
        email_address: "", password: ""
      } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_settings_user_path(users(:teammate))
    assert_response :success
    assert_select "form"
  end

  test "update modifies user" do
    patch settings_user_path(users(:teammate)), params: { user: {
      first_name: "Updated"
    } }

    assert_redirected_to settings_user_path(users(:teammate))
    assert_equal "Updated", users(:teammate).reload.first_name
  end

  test "update with blank password keeps current password" do
    original_digest = users(:teammate).password_digest

    patch settings_user_path(users(:teammate)), params: { user: {
      first_name: "Updated", password: "", password_confirmation: ""
    } }

    assert_redirected_to settings_user_path(users(:teammate))
    assert_equal original_digest, users(:teammate).reload.password_digest
  end

  test "update with invalid data renders form" do
    patch settings_user_path(users(:teammate)), params: { user: {
      first_name: ""
    } }

    assert_response :unprocessable_entity
  end

  test "destroy removes user" do
    assert_difference "User.count", -1 do
      delete settings_user_path(users(:teammate))
    end

    assert_redirected_to settings_users_path
  end

  test "cannot delete yourself" do
    assert_no_difference "User.count" do
      delete settings_user_path(users(:one))
    end

    assert_redirected_to settings_users_path
    assert_equal "You can't delete yourself.", flash[:alert]
  end

  test "requires authentication" do
    sign_out
    get settings_users_path
    assert_redirected_to new_session_path
  end

  test "scoped to account" do
    get settings_user_path(users(:two))
    assert_response :not_found
  end

  test "members can view index" do
    sign_in_as users(:teammate)
    get settings_users_path
    assert_response :success
  end

  test "members can view show" do
    sign_in_as users(:teammate)
    get settings_user_path(users(:one))
    assert_response :success
  end

  test "members cannot access new" do
    sign_in_as users(:teammate)
    get new_settings_user_path
    assert_response :redirect
  end

  test "members cannot create users" do
    sign_in_as users(:teammate)
    assert_no_difference "User.count" do
      post settings_users_path, params: { user: {
        first_name: "New", last_name: "User",
        email_address: "blocked@example.com",
        password: "password123", password_confirmation: "password123"
      } }
    end
    assert_response :redirect
  end

  test "members cannot edit users" do
    sign_in_as users(:teammate)
    get edit_settings_user_path(users(:one))
    assert_response :redirect
  end

  test "members cannot update users" do
    sign_in_as users(:teammate)
    patch settings_user_path(users(:one)), params: { user: { first_name: "Hacked" } }
    assert_response :redirect
    assert_equal "Daniel", users(:one).reload.first_name
  end

  test "members cannot destroy users" do
    sign_in_as users(:teammate)
    assert_no_difference "User.count" do
      delete settings_user_path(users(:one))
    end
    assert_response :redirect
  end
end
