require "net/http"

class Agent::Audio
  WHISPER_URL = "https://api.openai.com/v1/audio/transcriptions"

  TTS_PROVIDERS = {
    "openai"     => OpenaiTts,
    "elevenlabs" => ElevenlabsTts
  }.freeze

  attr_reader :agent

  def initialize(agent)
    @agent = agent
  end

  # ── TTS ──

  def speak(text, voice: nil, speed: nil)
    voice ||= resolved_voice
    speed ||= resolved_speed
    tts_provider.speak(text, voice: voice, speed: speed)
  end

  def tts_provider
    @tts_provider ||= build_tts_provider
  end

  def resolved_voice
    stored = agent_config("voice") || account_config("voice")
    return tts_provider_class.default_voice unless stored

    # If stored voice belongs to a different provider, fall back to default.
    # For ElevenLabs, accept known names and raw voice IDs (alphanumeric, 20 chars).
    if tts_provider_class == ElevenlabsTts
      return stored if ElevenlabsTts::VOICES.key?(stored) || stored.match?(/\A[a-zA-Z0-9]{15,}\z/)
    else
      return stored if tts_provider_class.voices.include?(stored)
    end

    tts_provider_class.default_voice
  end

  def resolved_speed
    (agent_config("tts_speed") || account_config("tts_speed") || "1.0").to_f
  end

  def tts_provider_name
    agent_config("tts_provider", inherit: true) ||
      account_config("tts_provider") ||
      "openai"
  end

  def tts_enabled?
    agent_config("tts_enabled") != "false"
  end

  def available?
    tts_enabled? && build_tts_provider.present?
  end

  def self.voices_for(provider_name)
    klass = TTS_PROVIDERS[provider_name]
    klass ? klass.voices : OpenaiTts::VOICES
  end

  # Returns voices with preview URLs for the given provider.
  # For ElevenLabs, fetches from API and filters by model compatibility.
  # For OpenAI, returns static list (no previews).
  def self.voices_with_previews(provider_name, api_key: nil, model: nil)
    case provider_name
    when "elevenlabs"
      return [] unless api_key
      voices = ElevenlabsTts.fetch_voices(api_key)
      return voices unless model
      voices.select { |v| v[:models].blank? || v[:models][model] == "fine_tuned" }
    else
      OpenaiTts::VOICES.map { |v| { id: v, name: v.capitalize, preview_url: nil } }
    end
  end

  # ── STT ──

  def transcribe(audio_io, filename:)
    if stt_provider_name == "local" && LocalWhisperStt.available?
      model = account_config("whisper_model") || LocalWhisperStt::DEFAULT_MODEL
      LocalWhisperStt.new(model: model).transcribe(audio_io, filename: filename)
    else
      transcribe_openai(audio_io, filename: filename)
    end
  end

  def stt_provider_name
    agent_config("stt_provider", inherit: true) ||
      account_config("stt_provider") ||
      "openai"
  end

  private
    def build_tts_provider
      name = tts_provider_name
      key = api_key_for(name)
      return nil unless key

      if name == "elevenlabs"
        model = agent_config("elevenlabs_model", inherit: true) ||
          account_config("elevenlabs_model") ||
          ElevenlabsTts::DEFAULT_MODEL
        tts_provider_class.new(key, model: model)
      else
        tts_provider_class.new(key)
      end
    end

    def tts_provider_class
      TTS_PROVIDERS.fetch(tts_provider_name, OpenaiTts)
    end

    def api_key_for(provider_name)
      kc_name = provider_name == "openai" ? "openai" : provider_name
      KeyChain.find_by(owner: agent, name: kc_name)&.api_key ||
        KeyChain.find_by(owner: agent.account, name: kc_name)&.api_key
    end

    def agent_config(key, inherit: false)
      val = agent.configs.find_by(key: key)&.value
      return nil if inherit && val == "inherit"
      val
    end

    def account_config(key)
      Config.find_by(configurable: agent.account, key: key)&.value
    end

    def transcribe_openai(audio_io, filename:)
      key = api_key_for("openai")
      raise Providers::Error, "OpenAI API key not configured" unless key

      boundary = SecureRandom.hex(16)
      body = build_multipart(boundary, audio_io, filename)

      uri = URI(WHISPER_URL)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{key}"
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      raise Providers::Error, "Whisper transcription failed: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("text")
    end

    def build_multipart(boundary, audio_io, filename)
      parts = []

      parts << "--#{boundary}\r\n"
      parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
      parts << "Content-Type: application/octet-stream\r\n\r\n"
      parts << audio_io.read
      parts << "\r\n"

      parts << "--#{boundary}\r\n"
      parts << "Content-Disposition: form-data; name=\"model\"\r\n\r\n"
      parts << "whisper-1"
      parts << "\r\n"

      parts << "--#{boundary}--\r\n"

      parts.join
    end
end
