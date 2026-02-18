require "test_helper"

class Settings::VoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "show renders voice settings page" do
    get settings_voice_path
    assert_response :success
  end

  test "update saves tts provider" do
    patch settings_voice_path, params: { voice_settings: { tts_provider: "elevenlabs", stt_provider: "openai" } }

    assert_redirected_to settings_voice_path
    assert_equal "elevenlabs", Config.find_by(configurable: accounts(:one), key: "tts_provider").value
  end

  test "update saves voice selection" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "openai", stt_provider: "openai", voice: "nova"
    } }

    assert_redirected_to settings_voice_path
    assert_equal "nova", Config.find_by(configurable: accounts(:one), key: "voice").value
  end

  test "update saves elevenlabs model" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "elevenlabs", stt_provider: "openai", elevenlabs_model: "eleven_v3"
    } }

    assert_redirected_to settings_voice_path
    assert_equal "eleven_v3", Config.find_by(configurable: accounts(:one), key: "elevenlabs_model").value
  end

  test "update saves tts speed" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "openai", stt_provider: "openai", tts_speed: "0.85"
    } }

    assert_redirected_to settings_voice_path
    assert_equal "0.85", Config.find_by(configurable: accounts(:one), key: "tts_speed").value
  end

  test "update saves stt provider" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "openai", stt_provider: "local"
    } }

    assert_redirected_to settings_voice_path
    assert_equal "local", Config.find_by(configurable: accounts(:one), key: "stt_provider").value
  end

  test "update saves elevenlabs api key to key chain" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "openai", stt_provider: "openai", elevenlabs_api_key: "xi-test-key-123"
    } }

    assert_redirected_to settings_voice_path
    kc = KeyChain.find_by(owner: accounts(:one), name: "elevenlabs")
    assert_equal "xi-test-key-123", kc.api_key
  end

  test "update saves openai api key and ensures provider exists" do
    patch settings_voice_path, params: { voice_settings: {
      tts_provider: "openai", stt_provider: "openai", openai_api_key: "sk-new-key"
    } }

    assert_redirected_to settings_voice_path
    assert accounts(:one).providers.exists?(name: "openai")
    assert_equal "sk-new-key", KeyChain.find_by(owner: accounts(:one), name: "openai").api_key
  end

  test "update ignores blank api keys" do
    assert_no_difference "KeyChain.count" do
      patch settings_voice_path, params: { voice_settings: {
        tts_provider: "openai", stt_provider: "openai", elevenlabs_api_key: ""
      } }
    end
  end

  test "show requires authentication" do
    sign_out
    get settings_voice_path
    assert_redirected_to new_session_path
  end
end
