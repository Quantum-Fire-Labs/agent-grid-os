require "test_helper"

class Agents::MemoryWipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "new renders form" do
    get new_agent_memory_wipe_path(@agent)
    assert_response :success
    assert_select "input[name=scope]"
  end

  test "create wipes everything" do
    assert @agent.memories.any?

    chat = @agent.account.chats.create!
    chat.participants.create!(participatable: @agent)
    chat.messages.create!(role: "user", content: "hello", sender: users(:one))

    post agent_memory_wipe_path(@agent), params: { scope: "everything" }

    assert_redirected_to agent_path(@agent)
    assert_equal 0, @agent.memories.count
    assert_equal 0, chat.messages.count
    assert Chat.exists?(chat.id), "wipe should preserve conversations and only delete messages"
  end

  test "create wipes memories since custom cutoff" do
    old_memory = @agent.memories.create!(content: "old memory", created_at: 2.days.ago)
    recent_memory = @agent.memories.create!(content: "recent memory", created_at: 1.hour.ago)

    post agent_memory_wipe_path(@agent), params: { scope: "custom", amount: "24", unit: "hours" }

    assert_redirected_to agent_path(@agent)
    assert Memory.exists?(old_memory.id)
    assert_not Memory.exists?(recent_memory.id)
  end

  test "create wipes chat messages since cutoff and preserves chats with remaining messages" do
    chat = @agent.account.chats.create!
    chat.participants.create!(participatable: @agent)
    chat.messages.create!(role: "user", content: "old msg", created_at: 2.days.ago,
                          sender: users(:one))
    recent_msg = chat.messages.create!(role: "assistant", content: "recent msg", created_at: 30.minutes.ago,
                                       sender: @agent)

    post agent_memory_wipe_path(@agent), params: { scope: "custom", amount: "1", unit: "hours" }

    assert_redirected_to agent_path(@agent)
    assert_not Message.exists?(recent_msg.id)
    assert Chat.exists?(chat.id), "chat with remaining messages should not be destroyed"
  end

  test "create destroys empty chats after message wipe" do
    chat = @agent.account.chats.create!
    chat.participants.create!(participatable: @agent)
    chat.messages.create!(role: "assistant", content: "recent msg", created_at: 10.minutes.ago,
                          sender: @agent)

    post agent_memory_wipe_path(@agent), params: { scope: "custom", amount: "30", unit: "minutes" }

    assert_redirected_to agent_path(@agent)
    assert_not Chat.exists?(chat.id), "empty chat should be destroyed"
  end

  test "member without access cannot reach agent" do
    sign_out
    sign_in_as users(:teammate)

    get new_agent_memory_wipe_path(@agent)
    assert_response :not_found
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    get new_agent_memory_wipe_path(other_agent)
    assert_response :not_found
  end
end
