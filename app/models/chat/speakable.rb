module Chat::Speakable
  extend ActiveSupport::Concern

  class TtsStream
    SENTENCE_BOUNDARY = /(?<=[.!?])\s+/

    attr_reader :chunks

    def initialize(chat, audio_service)
      @chat = chat
      @audio_service = audio_service
      @queue = Queue.new
      @chunks = []
      @last_sent_pos = 0
      @worker = Thread.new { process_queue }
    end

    def reset(current_text)
      remaining = current_text[@last_sent_pos..]&.strip
      @queue << remaining if remaining.present?
      @last_sent_pos = 0
    end

    def feed(accumulated)
      text = accumulated[@last_sent_pos..]
      return if text.nil? || text.empty?

      # Find the last sentence boundary in the unsent text
      last_match = nil
      text.scan(SENTENCE_BOUNDARY) { last_match = Regexp.last_match }
      return unless last_match

      # Everything up to (and including) the whitespace after the last complete sentence
      boundary_end = last_match.begin(0) + last_match[0].length
      complete = text[0, last_match.begin(0)]
      @last_sent_pos += boundary_end

      @queue << complete.strip if complete.strip.present?
    end

    def finish(message)
      # Flush remaining text
      remaining = message.content[@last_sent_pos..]&.strip
      @queue << remaining if remaining.present?
      @queue << :done

      @worker.join

      attach_combined_audio(message)
    end

    private

    def process_queue
      loop do
        sentence = @queue.pop
        break if sentence == :done

        mp3_data = @audio_service.speak(sentence)
        @chunks << mp3_data

        broadcast_audio_chunk(mp3_data)
      rescue => e
        Rails.logger.warn("TTS stream chunk failed: #{e.message}")
      end
    end

    def broadcast_audio_chunk(mp3_data)
      base64 = Base64.strict_encode64(mp3_data)
      data_uri = "data:audio/mpeg;base64,#{base64}"

      Turbo::StreamsChannel.broadcast_append_to(
        @chat,
        target: "audio-queue",
        html: %(<div data-audio-queue-target="chunk" data-src="#{data_uri}"></div>)
      )
    end

    # Concatenate MP3 chunks, stripping ID3 headers from chunks after the first.
    # Each TTS API response is a standalone MP3 file with its own ID3v2 header.
    # Naive concatenation embeds extra headers mid-stream, causing decoder pops.
    def combine_mp3_chunks(chunks)
      return chunks.first if chunks.size == 1

      parts = [ chunks.first ]
      chunks[1..].each { |chunk| parts << strip_id3v2(chunk) }
      parts.join
    end

    def strip_id3v2(data)
      return data unless data.byteslice(0, 3) == "ID3"

      # ID3v2 header: 10 bytes fixed, size in bytes 6-9 as syncsafe integer
      size_bytes = data.byteslice(6, 4).unpack("C4")
      tag_size = 10 + ((size_bytes[0] << 21) | (size_bytes[1] << 14) | (size_bytes[2] << 7) | size_bytes[3])
      data.byteslice(tag_size..) || data
    end

    def attach_combined_audio(message)
      return if @chunks.empty?

      combined = combine_mp3_chunks(@chunks)
      message.audio.attach(
        io: StringIO.new(combined),
        filename: "reply_#{message.id}.mp3",
        content_type: "audio/mpeg"
      )

      # Replace the synthesize-only player with the persistent audio player
      src = Rails.application.routes.url_helpers.rails_blob_path(message.audio, only_path: true)
      Turbo::StreamsChannel.broadcast_update_to(
        @chat,
        target: ActionView::RecordIdentifier.dom_id(message, :audio),
        html: <<~HTML
          <div class="audio-player" data-controller="audio-player" data-audio-player-autoplay-value="false">
            <button class="audio-player-btn" data-action="audio-player#toggle" data-audio-player-target="playBtn" type="button" aria-label="Play audio">
              <svg class="audio-player-icon-play" width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="6 3 20 12 6 21 6 3"/></svg>
              <svg class="audio-player-icon-pause" width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><rect x="5" y="3" width="4" height="18" rx="1"/><rect x="15" y="3" width="4" height="18" rx="1"/></svg>
            </button>
            <div class="audio-player-wave" data-audio-player-target="wave"><span></span><span></span><span></span><span></span><span></span></div>
            <div class="audio-player-track" data-audio-player-target="progress"><div class="audio-player-fill" data-audio-player-target="fill"></div></div>
            <span class="audio-player-time" data-audio-player-target="time">0:00</span>
            <audio src="#{src}" data-audio-player-target="audio" preload="metadata"></audio>
          </div>
        HTML
      )
    rescue => e
      Rails.logger.warn("TTS combined audio attach failed: #{e.message}")
    end
  end

  def start_tts_stream
    audio_service = Agent::Audio.new(agent)
    return nil unless audio_service.available?

    TtsStream.new(self, audio_service)
  end
end
