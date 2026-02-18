require "open3"

class Agent::Audio::LocalWhisperStt
  DEFAULT_MODEL = "base.en"

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def transcribe(audio_io, filename:)
    Dir.mktmpdir("whisper") do |dir|
      input_path = File.join(dir, filename)
      wav_path = File.join(dir, "audio.wav")
      File.binwrite(input_path, audio_io.read)

      # Convert to 16kHz mono WAV (whisper.cpp requirement)
      system("ffmpeg", "-i", input_path, "-ar", "16000", "-ac", "1", "-f", "wav", wav_path,
             "-y", "-loglevel", "error", exception: true)

      # Run whisper-cli and capture output
      output, status = Open3.capture2("whisper-cli", "-m", model_path, "-f", wav_path, "--no-timestamps", "-nt")
      raise Providers::Error, "whisper-cli failed (exit #{status.exitstatus})" unless status.success?

      output.strip
    end
  end

  def self.available?
    system("which", "whisper-cli", out: File::NULL, err: File::NULL)
  end

  private
    def model_path
      paths = [
        "/usr/share/whisper.cpp/models/ggml-#{@model}.bin",
        File.expand_path("~/.local/share/whisper.cpp/ggml-#{@model}.bin"),
        "ggml-#{@model}.bin"
      ]
      paths.find { |p| File.exist?(p) } || paths.first
    end
end
