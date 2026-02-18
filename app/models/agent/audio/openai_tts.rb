require "net/http"

class Agent::Audio::OpenaiTts
  URL = "https://api.openai.com/v1/audio/speech"

  VOICES = %w[alloy echo fable onyx nova shimmer].freeze
  DEFAULT_VOICE = "alloy"

  def self.voices     = VOICES
  def self.default_voice = DEFAULT_VOICE

  attr_reader :api_key

  def initialize(api_key)
    @api_key = api_key
  end

  def speak(text, voice: DEFAULT_VOICE, speed: 1.0)
    uri = URI(URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = { model: "tts-1", input: text, voice: voice, speed: speed.to_f.clamp(0.25, 4.0), response_format: "mp3" }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Providers::Error, "TTS generation failed: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end
end
