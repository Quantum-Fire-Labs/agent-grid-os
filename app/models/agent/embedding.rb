require "net/http"

class Agent::Embedding
  HOST  = "api.openai.com"
  PATH  = "/v1/embeddings"
  MODEL = "text-embedding-3-small"

  def initialize(account)
    @api_key = account.configs.find_by(key: "openai_api_key")&.value
  end

  def available?
    @api_key.present?
  end

  def embed(text)
    response = post(input: text)
    response&.dig("data", 0, "embedding")
  rescue => e
    Rails.logger.error("Agent::Embedding#embed failed: #{e.message}")
    nil
  end

  def embed_batch(texts)
    response = post(input: texts)
    return [] unless response

    response["data"]
      .sort_by { |item| item["index"] }
      .map { |item| item["embedding"] }
  rescue => e
    Rails.logger.error("Agent::Embedding#embed_batch failed: #{e.message}")
    []
  end

  private

    def post(input:)
      return nil unless available?

      uri = URI::HTTPS.build(host: HOST, path: PATH)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = { model: MODEL, input: input }.to_json

      response = http.request(request)
      data = JSON.parse(response.body)

      if data["error"]
        Rails.logger.error("Agent::Embedding API error: #{data.dig("error", "message")}")
        return nil
      end

      data
    end
end
