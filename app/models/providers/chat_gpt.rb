require "net/http"

class Providers::ChatGpt < Providers::Client
  HOST = "chatgpt.com"
  PATH = "/backend-api/codex/responses"

  def self.display_name = "OpenAI ChatGPT Subscription"

  MODELS = [
    { id: "gpt-5.3-codex", name: "GPT-5.3 Codex" },
    { id: "gpt-5.3-codex-spark", name: "GPT-5.3 Codex Spark" },
    { id: "gpt-5.2-codex", name: "GPT-5.2 Codex" },
    { id: "gpt-5.1-codex", name: "GPT-5.1 Codex" },
    { id: "gpt-5-codex", name: "GPT-5 Codex" },
    { id: "gpt-5-codex-mini", name: "GPT-5 Codex Mini" }
  ].freeze

  def self.models(_key_chain) = MODELS

  OAUTH_CONFIG = {
    client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
    token_url: "https://auth.openai.com/oauth/token",
    device_code_url: "https://auth.openai.com/api/accounts/deviceauth/usercode",
    device_token_url: "https://auth.openai.com/api/accounts/deviceauth/token"
  }.freeze

  def chat(messages:, model: nil, tools: nil, &on_token)
    key_chain = provider.key_chain
    raise Providers::Error, "ChatGPT not connected" unless key_chain&.access_token

    Providers::Oauth.ensure_fresh_token(
      key_chain: key_chain,
      client_id: OAUTH_CONFIG[:client_id],
      token_url: OAUTH_CONFIG[:token_url]
    )

    payload = build_payload(messages, resolved_model(model), tools)
    post(payload, key_chain) { |response| parse_stream(response, &on_token) }
  end

  def connected?(agent: nil)
    provider.key_chain(agent: agent)&.access_token.present?
  end

  private
    def post(payload, key_chain, &block)
      uri = URI::HTTPS.build(host: HOST, path: PATH)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{key_chain.access_token}"
      request["Content-Type"] = "application/json"
      request["originator"] = "opencode"
      request["ChatGPT-Account-Id"] = key_chain.oauth_account_id if key_chain.oauth_account_id
      request.body = payload.to_json

      http.request(request) { |resp| return block.call(resp) }
    end

    # Convert Chat Completions messages → Responses API payload
    def build_payload(messages, model, tools)
      instructions = nil
      input = []

      messages.each do |msg|
        role = msg[:role] || msg["role"]
        content = msg[:content] || msg["content"]

        case role
        when "system"
          instructions = [ instructions, content ].compact.join("\n\n")
        when "user"
          input << { type: "message", role: "user", content: content }
        when "assistant"
          tool_calls = msg[:tool_calls] || msg["tool_calls"]
          if tool_calls.present?
            tool_calls.each do |tc|
              func = tc[:function] || tc["function"] || tc
              fc_id = to_fc_id(tc[:id] || tc["id"])
              input << {
                type: "function_call",
                id: fc_id,
                call_id: fc_id,
                name: func[:name] || func["name"],
                arguments: func[:arguments] || func["arguments"]
              }
            end
          end
          input << { type: "message", role: "assistant", content: content } if content.present?
        when "tool"
          input << {
            type: "function_call_output",
            call_id: to_fc_id(msg[:tool_call_id] || msg["tool_call_id"]),
            output: content
          }
        end
      end

      payload = { model: model, stream: true, store: false }
      payload[:instructions] = instructions if instructions
      payload[:input] = input if input.any?
      payload[:tools] = flatten_tools(tools) if tools.present?
      payload
    end

    # Flatten tool definitions from Chat Completions format → Responses API format
    def flatten_tools(tools)
      tools.map do |tool|
        func = tool[:function] || tool["function"]
        next tool unless func

        {
          type: "function",
          name: func[:name] || func["name"],
          description: func[:description] || func["description"],
          parameters: func[:parameters] || func["parameters"]
        }.compact
      end
    end

    def parse_stream(response, &on_token)
      unless response.is_a?(Net::HTTPSuccess)
        body = +""
        response.read_body { |chunk| body << chunk }
        error = begin
          parsed = JSON.parse(body)
          parsed.dig("detail") || parsed.dig("error", "message")
        rescue
          nil
        end
        raise Providers::Error, error || "ChatGPT API error: #{response.code}"
      end

      content_parts = []
      tool_calls = {}
      current_tool_id = nil

      response.read_body do |chunk|
        chunk.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?("event: ")
          next unless line.start_with?("data: ")

          payload = line.delete_prefix("data: ").strip
          next if payload == "[DONE]"

          begin
            event = JSON.parse(payload)
          rescue JSON::ParserError
            next
          end

          case event["type"]
          when "response.output_text.delta"
            delta = event["delta"]
            if delta.present?
              content_parts << delta
              on_token&.call(delta)
            end
          when "response.output_item.added"
            item = event["item"]
            if item&.dig("type") == "function_call"
              id = item["id"] || item["call_id"]
              current_tool_id = id
              tool_calls[id] = { name: item["name"] || "", arguments: "" }
            end
          when "response.function_call_arguments.delta"
            delta = event["delta"]
            if delta.present? && current_tool_id && tool_calls[current_tool_id]
              tool_calls[current_tool_id][:arguments] += delta
            end
          when "response.output_item.done"
            item = event["item"]
            if item&.dig("type") == "function_call"
              id = item["id"] || item["call_id"]
              tool_calls[id] = { name: item["name"], arguments: item["arguments"] || "" }
            end
            current_tool_id = nil
          end
        end
      end

      Providers::Response.new(
        content: content_parts.join.presence,
        tool_calls: normalize_tool_calls(tool_calls),
        usage: {}
      )
    end

    def normalize_tool_calls(raw)
      return [] if raw.empty?

      raw.filter_map do |id, tc|
        next if id.blank? || tc[:name].blank?

        Providers::ToolCall.new(
          id: id,
          name: tc[:name],
          arguments: tc[:arguments]
        )
      end
    end

    # Convert internal call_xxx IDs → fc_xxx for the ChatGPT Responses API
    def to_fc_id(id)
      return id unless id
      id.start_with?("call_") ? id.sub("call_", "fc_") : "fc_#{id}"
    end
end
