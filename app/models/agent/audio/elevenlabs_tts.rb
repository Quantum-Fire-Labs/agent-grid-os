require "net/http"

class Agent::Audio::ElevenlabsTts
  URL = "https://api.elevenlabs.io/v1/text-to-speech"
  VOICES_URL = "https://api.elevenlabs.io/v1/voices"

  VOICES = {
    "rachel"  => "21m00Tcm4TlvDq8ikWAM",
    "drew"    => "29vD33N1CtxCmqQRPOHJ",
    "clyde"   => "2EiwWnXFnvU5JabPnv8n",
    "paul"    => "5Q0t7uMcjvnagumLfvZi",
    "domi"    => "AZnzlk1XvdvUeBnXmlld",
    "dave"    => "CYw3kZ02Hs0563khs1Fj",
    "fin"     => "D38z5RcWu1voky8WS1ja",
    "sarah"   => "EXAVITQu4vr4xnSDxMaL",
    "antoni"  => "ErXwobaYiN019PkySvjV",
    "thomas"  => "GBv7mTt0atIp3Br8iCZE",
    "charlie" => "IKne3meq5aSn9XLyUdCD",
    "emily"   => "LcfcDJNUP1GQjkzn1xUU",
    "elli"    => "MF3mGyEYCl7XYWbV9V6O",
    "callum"  => "N2lVS1w4EtoT3dr4eOWO",
    "josh"    => "TxGEqnHWrfWFTfGW9XjX",
    "arnold"  => "VR6AewLTigWG4xSOukaG",
    "adam"    => "pNInz6obpgDQGcFmaJgB",
    "sam"     => "yoZ06aMxZJJ28mfd3POQ"
  }.freeze

  MODELS = {
    "eleven_v3"               => { name: "Eleven v3", desc: "Most expressive", latency: "normal", languages: 74 },
    "eleven_multilingual_v2"  => { name: "Multilingual v2", desc: "Life-like, emotionally rich", latency: "normal", languages: 29 },
    "eleven_flash_v2_5"       => { name: "Flash v2.5", desc: "Ultra low latency", latency: "fastest", languages: 32 },
    "eleven_turbo_v2_5"       => { name: "Turbo v2.5", desc: "High quality, low latency", latency: "fast", languages: 32 },
    "eleven_turbo_v2"         => { name: "Turbo v2", desc: "Low latency, English only", latency: "fast", languages: 1 },
    "eleven_flash_v2"         => { name: "Flash v2", desc: "Ultra low latency, English only", latency: "fastest", languages: 1 },
    "eleven_monolingual_v1"   => { name: "English v1", desc: "Legacy", latency: "normal", languages: 1 },
    "eleven_multilingual_v1"  => { name: "Multilingual v1", desc: "Legacy", latency: "normal", languages: 9 }
  }.freeze

  DEFAULT_VOICE = "rachel"
  DEFAULT_MODEL = "eleven_flash_v2_5"

  def self.voices       = VOICES.keys
  def self.default_voice = DEFAULT_VOICE
  def self.models       = MODELS

  def self.fetch_voices(api_key)
    Rails.cache.fetch("elevenlabs_voices/#{api_key[0..7]}", expires_in: 10.minutes) do
      uri = URI(VOICES_URL)
      request = Net::HTTP::Get.new(uri)
      request["xi-api-key"] = api_key

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      next [] unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      (data["voices"] || []).map do |v|
        {
          id: v["voice_id"],
          name: v["name"],
          preview_url: v["preview_url"],
          labels: v["labels"] || {},
          models: v.dig("fine_tuning", "state") || {}
        }
      end.sort_by { |v| v[:name] }
    end
  rescue StandardError => e
    Rails.logger.warn("[ElevenLabs] Voice fetch failed: #{e.class}: #{e.message}")
    []
  end

  attr_reader :api_key, :model

  def initialize(api_key, model: DEFAULT_MODEL)
    @api_key = api_key
    @model = model
  end

  def speak(text, voice: DEFAULT_VOICE, speed: 1.0)
    voice_id = resolve_voice_id(voice)

    uri = URI("#{URL}/#{voice_id}")
    request = Net::HTTP::Post.new(uri)
    request["xi-api-key"] = api_key
    request["Content-Type"] = "application/json"
    request["Accept"] = "audio/mpeg"
    request.body = {
      text: text,
      model_id: model,
      voice_settings: { stability: 0.5, similarity_boost: 0.75, speed: speed.to_f.clamp(0.7, 1.2) }
    }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Providers::Error, "ElevenLabs TTS failed: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def fetch_voices
    self.class.fetch_voices(api_key)
  end

  private
    def resolve_voice_id(voice)
      VOICES[voice.to_s.downcase] || voice
    end
end
