require "test_helper"

class Providers::ToolCallTest < ActiveSupport::TestCase
  test "normalize_id returns nil for nil" do
    assert_nil Providers::ToolCall.normalize_id(nil)
  end

  test "normalize_id preserves call_ prefix" do
    assert_equal "call_abc123", Providers::ToolCall.normalize_id("call_abc123")
  end

  test "normalize_id converts fc_ prefix to call_" do
    assert_equal "call_abc123", Providers::ToolCall.normalize_id("fc_abc123")
  end

  test "normalize_id wraps raw UUIDs with call_ prefix" do
    assert_equal "call_019c8c61-abcd", Providers::ToolCall.normalize_id("019c8c61-abcd")
  end

  test "normalize_id wraps async_ ids with call_ prefix" do
    assert_equal "call_async_abc", Providers::ToolCall.normalize_id("async_abc")
  end

  test "initialize normalizes id" do
    tc = Providers::ToolCall.new(id: "fc_xyz", name: "test", arguments: "{}")
    assert_equal "call_xyz", tc.id
  end
end
