require "test_helper"

class Providers::ChatGptTest < ActiveSupport::TestCase
  setup do
    @provider = providers(:chatgpt)
    @client = @provider.client
  end

  test "client is ChatGpt instance" do
    assert_instance_of Providers::ChatGpt, @client
  end

  test "connected? returns true when access_token present" do
    assert @client.connected?
  end

  test "connected? returns false when no key_chain" do
    key_chains(:chatgpt).destroy!
    assert_not @client.connected?
  end

  test "chat raises when not connected" do
    key_chains(:chatgpt).destroy!
    error = assert_raises(Providers::Error) { @client.chat(messages: []) }
    assert_equal "ChatGPT not connected", error.message
  end

  test "build_payload converts system message to instructions" do
    messages = [ { role: "system", content: "You are helpful." } ]
    payload = @client.send(:build_payload, messages, "gpt-4o", nil)

    assert_equal "You are helpful.", payload[:instructions]
    assert_equal "gpt-4o", payload[:model]
    assert payload[:stream]
    assert_not payload[:store]
  end

  test "build_payload converts user message to input item" do
    messages = [ { role: "user", content: "Hello" } ]
    payload = @client.send(:build_payload, messages, "gpt-4o", nil)

    assert_equal 1, payload[:input].size
    assert_equal({ type: "message", role: "user", content: "Hello" }, payload[:input].first)
  end

  test "build_payload converts assistant tool calls with fc_ id prefix" do
    messages = [ {
      role: "assistant",
      content: nil,
      tool_calls: [ {
        id: "call_abc123",
        function: { name: "web_fetch", arguments: '{"url":"https://example.com"}' }
      } ]
    } ]
    payload = @client.send(:build_payload, messages, "gpt-4o", nil)

    item = payload[:input].first
    assert_equal "function_call", item[:type]
    assert_equal "fc_abc123", item[:id]
    assert_equal "fc_abc123", item[:call_id]
    assert_equal "web_fetch", item[:name]
  end

  test "build_payload converts tool result with fc_ id prefix" do
    messages = [ { role: "tool", tool_call_id: "call_abc123", content: "result data" } ]
    payload = @client.send(:build_payload, messages, "gpt-4o", nil)

    item = payload[:input].first
    assert_equal "function_call_output", item[:type]
    assert_equal "fc_abc123", item[:call_id]
    assert_equal "result data", item[:output]
  end

  test "build_payload concatenates multiple system messages" do
    messages = [
      { role: "system", content: "First instruction." },
      { role: "system", content: "Second instruction." }
    ]
    payload = @client.send(:build_payload, messages, "gpt-4o", nil)
    assert_equal "First instruction.\n\nSecond instruction.", payload[:instructions]
  end

  test "build_payload flattens tool definitions" do
    tools = [ {
      type: "function",
      function: { name: "remember", description: "Store a memory", parameters: { type: "object" } }
    } ]
    payload = @client.send(:build_payload, [], "gpt-4o", tools)

    tool = payload[:tools].first
    assert_equal "function", tool[:type]
    assert_equal "remember", tool[:name]
    assert_equal "Store a memory", tool[:description]
    assert_nil tool[:function]  # nested wrapper removed
  end

  test "parse_stream extracts content and calls on_token" do
    tokens = []
    chunks = [
      sse_event("response.output_text.delta", { delta: "Hello" }),
      sse_event("response.output_text.delta", { delta: " world" }),
      "data: [DONE]\n\n"
    ]

    response = stub_streaming_response(200, chunks)
    result = @client.send(:parse_stream, response) { |t| tokens << t }

    assert_equal "Hello world", result.content
    assert_equal [ "Hello", " world" ], tokens
  end

  test "parse_stream assembles tool calls" do
    chunks = [
      sse_event("response.output_item.added", { item: { type: "function_call", id: "fc_xyz", name: "remember", arguments: "" } }),
      sse_event("response.function_call_arguments.delta", { delta: '{"content":' }),
      sse_event("response.function_call_arguments.delta", { delta: '"test"}' }),
      sse_event("response.output_item.done", { item: { type: "function_call", id: "fc_xyz", name: "remember", arguments: '{"content":"test"}' } }),
      "data: [DONE]\n\n"
    ]

    response = stub_streaming_response(200, chunks)
    result = @client.send(:parse_stream, response) { |_| }

    assert_equal 1, result.tool_calls.size
    tc = result.tool_calls.first
    assert_equal "call_xyz", tc.id  # fc_ converted back to call_
    assert_equal "remember", tc.name
    assert_equal '{"content":"test"}', tc.arguments
  end

  test "parse_stream raises on error response" do
    response = stub_streaming_response(401, [ '{"detail":"Unauthorized"}' ])

    error = assert_raises(Providers::Error) do
      @client.send(:parse_stream, response) { |_| }
    end
    assert_equal "Unauthorized", error.message
  end

  test "to_fc_id converts call_ prefix to fc_" do
    assert_equal "fc_abc", @client.send(:to_fc_id, "call_abc")
  end

  test "to_fc_id passes through non-call_ ids" do
    assert_equal "fc_abc", @client.send(:to_fc_id, "fc_abc")
  end

  test "from_fc_id converts fc_ prefix to call_" do
    assert_equal "call_abc", @client.send(:from_fc_id, "fc_abc")
  end

  test "from_fc_id passes through non-fc_ ids" do
    assert_equal "call_abc", @client.send(:from_fc_id, "call_abc")
  end

  private
    def stub_streaming_response(code, chunks)
      klass = code == 200 ? Net::HTTPOK : Net::HTTPUnauthorized
      response = klass.new("1.1", code.to_s, "")
      body = chunks.join
      response.define_singleton_method(:read_body) do |&block|
        if block
          block.call(body)
        else
          body
        end
      end
      response
    end

    def sse_event(type, data)
      "event: #{type}\ndata: #{data.merge(type: type).to_json}\n\n"
    end
end
