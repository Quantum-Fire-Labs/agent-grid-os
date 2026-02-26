require "test_helper"

class ChatTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "archive! sets archived_at" do
    assert_nil @chat.archived_at
    @chat.archive!
    assert_not_nil @chat.reload.archived_at
  end

  test "unarchive! clears archived_at" do
    @chat.update!(archived_at: Time.current)
    @chat.unarchive!
    assert_nil @chat.reload.archived_at
  end

  test "archived? returns true when archived_at is set" do
    assert_not @chat.archived?
    @chat.update!(archived_at: Time.current)
    assert @chat.archived?
  end

  test "active scope excludes archived chats" do
    @chat.update!(archived_at: Time.current)
    assert_not_includes Chat.active, @chat
  end

  test "archived scope includes only archived chats" do
    assert_not_includes Chat.archived, @chat
    @chat.update!(archived_at: Time.current)
    assert_includes Chat.archived, @chat
  end
end
