require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @chat = chats(:one)
  end

  test "index shows active chats by default" do
    get chats_path
    assert_response :success
  end

  test "index shows archived chats when archived param present" do
    @chat.update!(archived_at: Time.current)
    get chats_path(archived: 1)
    assert_response :success
  end

  test "index excludes archived chats from default view" do
    @chat.update!(archived_at: Time.current)
    get chats_path
    assert_response :success
    assert_no_match @chat.display_name(viewer: users(:one)), response.body
  end

  test "destroy deletes chat and redirects" do
    assert_difference "Chat.count", -1 do
      delete chat_path(@chat)
    end
    assert_redirected_to chats_path
  end
end
