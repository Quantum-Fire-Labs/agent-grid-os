require "net/http"

class Providers::OpenRouter < Providers::Client
  HOST = "openrouter.ai"
  PATH = "/api/v1/chat/completions"

  MODELS_PATH = "/api/v1/models"

  def self.display_name = "OpenRouter"

  def self.models(key_chain)
    return [] unless key_chain&.api_key

    Rails.cache.fetch("provider_models/openrouter", expires_in: 5.minutes) do
      uri = URI::HTTPS.build(host: HOST, path: MODELS_PATH)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.path)
      request["Authorization"] = "Bearer #{key_chain.api_key}"

      response = http.request(request)
      data = JSON.parse(response.body)

      (data["data"] || []).map { |m| { id: m["id"], name: m["name"] || m["id"] } }
        .sort_by { |m| m[:name].downcase }
    end
  rescue StandardError
    []
  end

  def connected?(agent: nil)
    provider.key_chain(agent: agent)&.api_key.present?
  end

  def chat(messages:, model: nil, tools: nil, &on_token)
    payload = {
      model: resolved_model(model),
      messages: messages
    }
    payload[:tools] = tools if tools.present?
    payload[:stream] = true if on_token

    if on_token
      post(payload) { |response| parse_stream(response, &on_token) }
    else
      parse_response(post(payload))
    end
  end

  private

    def post(payload, &block)
      uri = URI::HTTPS.build(host: HOST, path: PATH)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{provider.key_chain&.api_key}"
      request["Content-Type"] = "application/json"
      request["HTTP-Referer"] = "https://thegrid.app"
      request["X-Title"] = "TheGrid"
      request.body = payload.to_json

      if block
        http.request(request) { |resp| return block.call(resp) }
      else
        http.request(request)
      end
    end

    def parse_response(response)
      data = JSON.parse(response.body)

      if data["error"]
        raise Providers::Error, data["error"]["message"]
      end

      choice = data.dig("choices", 0)
      message = choice&.dig("message") || {}

      Providers::Response.new(
        content: message["content"],
        tool_calls: normalize_tool_calls(message["tool_calls"]),
        usage: data["usage"] || {}
      )
    end

    def parse_stream(response, &on_token)
      unless response.is_a?(Net::HTTPSuccess)
        body = +""
        response.read_body { |chunk| body << chunk }
        error = begin; JSON.parse(body).dig("error", "message"); rescue; nil; end
        raise Providers::Error, error || "API error: #{response.code}"
      end

      content_parts = []
      tool_calls = {}
      usage = {}

      response.read_body do |chunk|
        chunk.each_line do |line|
          line = line.strip
          next unless line.start_with?("data: ")

          payload = line.delete_prefix("data: ").strip
          break if payload == "[DONE]"

          begin
            event = JSON.parse(payload)
          rescue JSON::ParserError
            next
          end
          if event["error"]
            raise Providers::Error, event["error"]["message"] || "Unknown API error"
          end

          usage = event["usage"] if event["usage"]

          choice = event.dig("choices", 0)
          next unless choice

          delta = choice["delta"] || {}

          if delta["content"].present?
            content_parts << delta["content"]
            on_token.call(delta["content"])
          end

          (delta["tool_calls"] || []).each do |tc|
            idx = tc["index"] || 0
            tool_calls[idx] ||= { "id" => "", "type" => "function", "function" => { "name" => "", "arguments" => "" } }
            tool_calls[idx]["id"] = tc["id"] if tc["id"]
            tool_calls[idx]["function"]["name"] = tc.dig("function", "name") if tc.dig("function", "name")
            tool_calls[idx]["function"]["arguments"] += tc.dig("function", "arguments").to_s
          end
        end
      end

      content = content_parts.join.presence

      Providers::Response.new(
        content: content,
        tool_calls: normalize_tool_calls(tool_calls.sort.map(&:last)),
        usage: usage
      )
    end

    def normalize_tool_calls(raw)
      return [] if raw.blank?

      raw.map do |tc|
        Providers::ToolCall.new(
          id: tc["id"],
          name: tc.dig("function", "name"),
          arguments: tc.dig("function", "arguments")
        )
      end
    end
end
