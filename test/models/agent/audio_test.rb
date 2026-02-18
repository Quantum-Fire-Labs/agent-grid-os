require "test_helper"

class Agent::AudioTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one) # account :one already has openai provider + key_chain fixtures
    @audio = Agent::Audio.new(@agent)
  end

  # ── Legacy constants ──

  test "VOICES contains expected voices" do
    assert_includes Agent::Audio::OpenaiTts::VOICES, "alloy"
    assert_includes Agent::Audio::OpenaiTts::VOICES, "nova"
    assert_equal 6, Agent::Audio::OpenaiTts::VOICES.size
  end

  # ── Voice resolution ──

  test "resolved_voice returns default when no config set" do
    assert_equal "alloy", @audio.resolved_voice
  end

  test "resolved_voice returns agent config voice" do
    @agent.configs.create!(key: "voice", value: "nova")
    assert_equal "nova", Agent::Audio.new(@agent).resolved_voice
  end

  test "resolved_voice falls back to account config" do
    Config.create!(configurable: @agent.account, key: "voice", value: "echo")
    assert_equal "echo", Agent::Audio.new(@agent).resolved_voice
  end

  test "agent voice overrides account voice" do
    Config.create!(configurable: @agent.account, key: "voice", value: "echo")
    @agent.configs.create!(key: "voice", value: "fable")
    assert_equal "fable", Agent::Audio.new(@agent).resolved_voice
  end

  # ── TTS provider resolution ──

  test "tts_provider_name defaults to openai" do
    assert_equal "openai", @audio.tts_provider_name
  end

  test "tts_provider_name reads from agent config" do
    @agent.configs.create!(key: "tts_provider", value: "elevenlabs")
    assert_equal "elevenlabs", Agent::Audio.new(@agent).tts_provider_name
  end

  test "tts_provider_name treats inherit as fallthrough" do
    @agent.configs.create!(key: "tts_provider", value: "inherit")
    assert_equal "openai", Agent::Audio.new(@agent).tts_provider_name
  end

  test "tts_provider_name falls back to account config" do
    Config.create!(configurable: @agent.account, key: "tts_provider", value: "elevenlabs")
    assert_equal "elevenlabs", Agent::Audio.new(@agent).tts_provider_name
  end

  # ── STT provider resolution ──

  test "stt_provider_name defaults to openai" do
    assert_equal "openai", @audio.stt_provider_name
  end

  test "stt_provider_name reads from agent config" do
    @agent.configs.create!(key: "stt_provider", value: "local")
    assert_equal "local", Agent::Audio.new(@agent).stt_provider_name
  end

  test "stt_provider_name treats inherit as fallthrough" do
    @agent.configs.create!(key: "stt_provider", value: "inherit")
    assert_equal "openai", Agent::Audio.new(@agent).stt_provider_name
  end

  # ── Available? ──

  test "available? returns true when openai key exists" do
    assert @audio.available?
  end

  test "available? returns false when no api key for provider" do
    agent = agents(:two) # account :two has no openai key_chain
    assert_not Agent::Audio.new(agent).available?
  end

  test "available? checks elevenlabs key when provider is elevenlabs" do
    @agent.configs.create!(key: "tts_provider", value: "elevenlabs")
    # No elevenlabs key exists
    assert_not Agent::Audio.new(@agent).available?
  end

  test "available? returns true for elevenlabs when key exists" do
    @agent.configs.create!(key: "tts_provider", value: "elevenlabs")
    KeyChain.create!(owner: @agent.account, name: "elevenlabs", secrets: { "api_key" => "xi-test" })
    assert Agent::Audio.new(@agent).available?
  end

  # ── voices_for class method ──

  test "voices_for returns openai voices" do
    assert_equal Agent::Audio::OpenaiTts::VOICES, Agent::Audio.voices_for("openai")
  end

  test "voices_for returns elevenlabs voice names" do
    voices = Agent::Audio.voices_for("elevenlabs")
    assert_includes voices, "rachel"
    assert_includes voices, "adam"
  end

  test "voices_for returns openai voices for unknown provider" do
    assert_equal Agent::Audio::OpenaiTts::VOICES, Agent::Audio.voices_for("unknown")
  end

  # ── Speed resolution ──

  test "resolved_speed defaults to 1.0" do
    assert_equal 1.0, @audio.resolved_speed
  end

  test "resolved_speed reads from agent config" do
    @agent.configs.create!(key: "tts_speed", value: "0.8")
    assert_equal 0.8, Agent::Audio.new(@agent).resolved_speed
  end

  test "resolved_speed falls back to account config" do
    Config.create!(configurable: @agent.account, key: "tts_speed", value: "1.15")
    assert_equal 1.15, Agent::Audio.new(@agent).resolved_speed
  end

  test "agent speed overrides account speed" do
    Config.create!(configurable: @agent.account, key: "tts_speed", value: "0.9")
    @agent.configs.create!(key: "tts_speed", value: "1.1")
    assert_equal 1.1, Agent::Audio.new(@agent).resolved_speed
  end

  # ── TTS enabled ──

  test "tts_enabled? returns true by default" do
    assert @audio.tts_enabled?
  end

  test "tts_enabled? returns false when disabled" do
    @agent.configs.create!(key: "tts_enabled", value: "false")
    assert_not Agent::Audio.new(@agent).tts_enabled?
  end

  test "available? returns false when tts disabled" do
    @agent.configs.create!(key: "tts_enabled", value: "false")
    assert_not Agent::Audio.new(@agent).available?
  end

  # ── voices_with_previews class method ──

  test "voices_with_previews returns openai voices with structure" do
    voices = Agent::Audio.voices_with_previews("openai")
    assert_equal 6, voices.size
    voice = voices.first
    assert_equal "alloy", voice[:id]
    assert_equal "Alloy", voice[:name]
    assert_nil voice[:preview_url]
  end

  test "voices_with_previews returns empty for elevenlabs without api key" do
    assert_equal [], Agent::Audio.voices_with_previews("elevenlabs")
  end

  # ── ElevenLabs model config ──

  test "elevenlabs provider uses configured model" do
    @agent.configs.create!(key: "tts_provider", value: "elevenlabs")
    Config.create!(configurable: @agent.account, key: "elevenlabs_model", value: "eleven_turbo_v2")
    KeyChain.create!(owner: @agent.account, name: "elevenlabs", secrets: { "api_key" => "xi-test" })

    audio = Agent::Audio.new(@agent)
    assert_equal "eleven_turbo_v2", audio.tts_provider.model
  end

  test "elevenlabs provider defaults to flash v2.5" do
    @agent.configs.create!(key: "tts_provider", value: "elevenlabs")
    KeyChain.create!(owner: @agent.account, name: "elevenlabs", secrets: { "api_key" => "xi-test" })

    audio = Agent::Audio.new(@agent)
    assert_equal "eleven_flash_v2_5", audio.tts_provider.model
  end

  # ── Multipart builder (STT) ──

  test "transcribe builds correct multipart body" do
    io = StringIO.new("fake audio data")
    body = @audio.send(:build_multipart, "test-boundary", io, "voice.webm")

    assert_includes body, "Content-Disposition: form-data; name=\"file\"; filename=\"voice.webm\""
    assert_includes body, "fake audio data"
    assert_includes body, "name=\"model\""
    assert_includes body, "whisper-1"
    assert_includes body, "--test-boundary--"
  end
end

class Agent::Audio::OpenaiTtsTest < ActiveSupport::TestCase
  test "voices returns expected list" do
    assert_equal %w[alloy echo fable onyx nova shimmer], Agent::Audio::OpenaiTts.voices
  end

  test "default_voice is alloy" do
    assert_equal "alloy", Agent::Audio::OpenaiTts.default_voice
  end
end

class Agent::Audio::ElevenlabsTtsTest < ActiveSupport::TestCase
  test "voices returns voice name strings" do
    voices = Agent::Audio::ElevenlabsTts.voices
    assert_includes voices, "rachel"
    assert_includes voices, "drew"
    assert voices.all? { |v| v.is_a?(String) }
  end

  test "default_voice is rachel" do
    assert_equal "rachel", Agent::Audio::ElevenlabsTts.default_voice
  end

  test "resolve_voice_id maps name to id" do
    tts = Agent::Audio::ElevenlabsTts.new("fake-key")
    assert_equal "21m00Tcm4TlvDq8ikWAM", tts.send(:resolve_voice_id, "rachel")
  end

  test "resolve_voice_id passes through raw IDs" do
    tts = Agent::Audio::ElevenlabsTts.new("fake-key")
    assert_equal "custom-voice-id-123", tts.send(:resolve_voice_id, "custom-voice-id-123")
  end

  test "MODELS contains expected model entries" do
    models = Agent::Audio::ElevenlabsTts::MODELS
    assert models.key?("eleven_flash_v2_5")
    assert models.key?("eleven_v3")
    assert_equal "Flash v2.5", models["eleven_flash_v2_5"][:name]
  end

  test "default model is eleven_flash_v2_5" do
    assert_equal "eleven_flash_v2_5", Agent::Audio::ElevenlabsTts::DEFAULT_MODEL
  end

  test "initialize accepts model parameter" do
    tts = Agent::Audio::ElevenlabsTts.new("fake-key", model: "eleven_v3")
    assert_equal "eleven_v3", tts.model
  end
end

class Agent::Audio::LocalWhisperSttTest < ActiveSupport::TestCase
  test "available? returns boolean" do
    result = Agent::Audio::LocalWhisperStt.available?
    assert_includes [ true, false ], result
  end
end
