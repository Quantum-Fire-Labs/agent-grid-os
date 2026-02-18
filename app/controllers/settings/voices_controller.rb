class Settings::VoicesController < ApplicationController
  before_action :require_admin

  def show
    @tts_provider = account_config("tts_provider") || "openai"
    @stt_provider = account_config("stt_provider") || "openai"
    @voice = account_config("voice")
    @whisper_model = account_config("whisper_model") || Agent::Audio::LocalWhisperStt::DEFAULT_MODEL
    @openai_connected = Current.account.providers.find_by(name: "openai")&.connected? || false
    @elevenlabs_key = KeyChain.find_by(owner: Current.account, name: "elevenlabs")&.api_key
    @elevenlabs_connected = @elevenlabs_key.present?
    @elevenlabs_model = account_config("elevenlabs_model") || Agent::Audio::ElevenlabsTts::DEFAULT_MODEL
    @tts_speed = (account_config("tts_speed") || "1.0").to_f
    @local_whisper_available = Agent::Audio::LocalWhisperStt.available?

    api_key = @tts_provider == "elevenlabs" ? @elevenlabs_key : nil
    @voices = Agent::Audio.voices_with_previews(@tts_provider, api_key: api_key, model: @elevenlabs_model)
  end

  def update
    voice_settings = params[:voice_settings]

    save_config("tts_provider", voice_settings[:tts_provider])
    save_config("stt_provider", voice_settings[:stt_provider])
    save_config("voice", voice_settings[:voice]) if voice_settings[:voice].present?
    save_config("elevenlabs_model", voice_settings[:elevenlabs_model]) if voice_settings[:elevenlabs_model].present?
    save_config("whisper_model", voice_settings[:whisper_model]) if voice_settings[:whisper_model].present?
    save_config("tts_speed", voice_settings[:tts_speed]) if voice_settings[:tts_speed].present?

    save_api_key("openai", voice_settings[:openai_api_key], create_provider: true) if voice_settings[:openai_api_key].present?
    save_api_key("elevenlabs", voice_settings[:elevenlabs_api_key]) if voice_settings[:elevenlabs_api_key].present?

    redirect_to settings_voice_path, notice: "Voice settings saved."
  end

  private
    def account_config(key)
      Config.find_by(configurable: Current.account, key: key)&.value
    end

    def save_config(key, value)
      return if value.blank?
      config = Config.find_or_initialize_by(configurable: Current.account, key: key)
      config.update!(value: value)
    end

    def save_api_key(name, key, create_provider: false)
      Current.account.providers.find_or_create_by!(name: name) if create_provider

      kc = Current.account.key_chains.find_or_initialize_by(name: name)
      kc.secrets = (kc.secrets || {}).merge("api_key" => key)
      kc.save!
    end
end
