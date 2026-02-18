require "test_helper"

class Providers::OpenAiTest < ActiveSupport::TestCase
  setup do
    @provider = providers(:openai)
    @client = @provider.client
  end

  test "client is OpenAi instance" do
    assert_instance_of Providers::OpenAi, @client
  end

  test "resolves model from provider" do
    assert_equal "gpt-4o-mini", @client.send(:resolved_model, nil)
  end

  test "resolves explicit model over provider default" do
    assert_equal "gpt-4o", @client.send(:resolved_model, "gpt-4o")
  end

  test "parse_response extracts content" do
    response = stub_response(200, {
      choices: [ { message: { content: "Hello!", tool_calls: nil } } ],
      usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
    })

    result = @client.send(:parse_response, response)

    assert_equal "Hello!", result.content
    assert_empty result.tool_calls
    assert_equal 15, result.usage["total_tokens"]
  end

  test "parse_response raises on error" do
    response = stub_response(400, {
      error: { message: "Invalid API key" }
    })

    error = assert_raises(Providers::Error) { @client.send(:parse_response, response) }
    assert_equal "Invalid API key", error.message
  end

  test "parse_response extracts tool calls" do
    response = stub_response(200, {
      choices: [ {
        message: {
          content: nil,
          tool_calls: [ {
            id: "call_abc123",
            type: "function",
            function: { name: "web_fetch", arguments: '{"url":"https://example.com"}' }
          } ]
        }
      } ],
      usage: {}
    })

    result = @client.send(:parse_response, response)

    assert_nil result.content
    assert_equal 1, result.tool_calls.size
    assert_equal "call_abc123", result.tool_calls.first.id
    assert_equal "web_fetch", result.tool_calls.first.name
    assert_equal '{"url":"https://example.com"}', result.tool_calls.first.arguments
  end

  test "parse_stream extracts content and calls on_token" do
    tokens = []
    chunks = [
      sse_data({ choices: [ { delta: { content: "Hello" } } ] }),
      sse_data({ choices: [ { delta: { content: " world" } } ] }),
      sse_data({ usage: { prompt_tokens: 10, completion_tokens: 2, total_tokens: 12 } }),
      "data: [DONE]\n\n"
    ]

    response = stub_streaming_response(200, chunks)
    result = @client.send(:parse_stream, response) { |t| tokens << t }

    assert_equal "Hello world", result.content
    assert_equal [ "Hello", " world" ], tokens
    assert_equal 12, result.usage["total_tokens"]
  end

  test "parse_stream assembles tool calls from deltas" do
    chunks = [
      sse_data({ choices: [ { delta: { tool_calls: [ { index: 0, id: "call_xyz", function: { name: "remember", arguments: "" } } ] } } ] }),
      sse_data({ choices: [ { delta: { tool_calls: [ { index: 0, function: { arguments: '{"content":' } } ] } } ] }),
      sse_data({ choices: [ { delta: { tool_calls: [ { index: 0, function: { arguments: '"test"}' } } ] } } ] }),
      "data: [DONE]\n\n"
    ]

    response = stub_streaming_response(200, chunks)
    result = @client.send(:parse_stream, response) { |_| }

    assert_equal 1, result.tool_calls.size
    tc = result.tool_calls.first
    assert_equal "call_xyz", tc.id
    assert_equal "remember", tc.name
    assert_equal '{"content":"test"}', tc.arguments
  end

  test "parse_stream raises on error response" do
    response = stub_streaming_response(401, [ '{"error":{"message":"Incorrect API key"}}' ])

    error = assert_raises(Providers::Error) do
      @client.send(:parse_stream, response) { |_| }
    end
    assert_equal "Incorrect API key", error.message
  end

  test "parse_stream raises on streamed error event" do
    chunks = [
      sse_data({ error: { message: "Rate limit exceeded" } })
    ]

    response = stub_streaming_response(200, chunks)

    assert_raises(Providers::Error) do
      @client.send(:parse_stream, response) { |_| }
    end
  end

  private
    def stub_response(code, body)
      response = Net::HTTPResponse::CODE_TO_OBJ[code.to_s].new("1.1", code.to_s, "")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body.to_json)
      response
    end

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

    def sse_data(hash)
      "data: #{hash.to_json}\n\n"
    end
end
