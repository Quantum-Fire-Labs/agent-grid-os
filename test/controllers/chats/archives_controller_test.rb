require "test_helper"

class Chats::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @chat = chats(:one)
  end

  test "create archives the chat" do
    post chat_archive_path(@chat)

    assert_redirected_to chats_path
    assert @chat.reload.archived?
  end

  test "destroy unarchives the chat" do
    @chat.update!(archived_at: Time.current)

    delete chat_archive_path(@chat)

    assert_redirected_to chats_path(archived: 1)
    assert_not @chat.reload.archived?
  end

  test "non-participant cannot archive chat" do
    sign_out
    sign_in_as users(:two)

    post chat_archive_path(@chat)
    assert_response :forbidden
  end
end
