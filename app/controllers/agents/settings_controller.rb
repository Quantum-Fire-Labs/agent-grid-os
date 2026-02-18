class Agents::SettingsController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def show
    audio = Agent::Audio.new(@agent)
    @tts_provider = agent_config("tts_provider") || "inherit"
    @stt_provider = agent_config("stt_provider") || "inherit"
    @current_voice = agent_config("voice") || audio.resolved_voice
    @tts_enabled = agent_config("tts_enabled") != "false"
    @effective_tts_provider = audio.tts_provider_name
    @tts_speed = agent_config("tts_speed") || ""
    @account_voice = Config.find_by(configurable: Current.account, key: "voice")&.value
    @elevenlabs_model = agent_config("elevenlabs_model") ||
      Config.find_by(configurable: Current.account, key: "elevenlabs_model")&.value ||
      Agent::Audio::ElevenlabsTts::DEFAULT_MODEL

    elevenlabs_key = KeyChain.find_by(owner: @agent, name: "elevenlabs")&.api_key ||
      KeyChain.find_by(owner: Current.account, name: "elevenlabs")&.api_key
    api_key = @effective_tts_provider == "elevenlabs" ? elevenlabs_key : nil
    @voices = Agent::Audio.voices_with_previews(@effective_tts_provider, api_key: api_key, model: @elevenlabs_model)
  end

  def update
    settings = params[:agent_settings]

    save_config("voice", settings[:voice]) if settings[:voice].present?
    save_config("tts_provider", settings[:tts_provider]) if settings.key?(:tts_provider)
    save_config("stt_provider", settings[:stt_provider]) if settings.key?(:stt_provider)
    save_config("tts_enabled", settings[:tts_enabled]) if settings.key?(:tts_enabled)
    save_config("tts_speed", settings[:tts_speed]) if settings[:tts_speed].present?
    save_config("elevenlabs_model", settings[:elevenlabs_model]) if settings[:elevenlabs_model].present?

    if settings.key?(:workspace_enabled)
      @agent.update!(workspace_enabled: settings[:workspace_enabled] == "1")
    end

    redirect_to agent_settings_path(@agent), notice: "Settings saved."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def agent_config(key)
      @agent.configs.find_by(key: key)&.value
    end

    def save_config(key, value)
      config = @agent.configs.find_or_initialize_by(key: key)
      config.update!(value: value)
    end
end
