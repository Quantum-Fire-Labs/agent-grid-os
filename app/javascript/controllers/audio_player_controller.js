import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "playBtn", "progress", "fill", "time", "wave"]
  static values = { autoplay: Boolean, synthesizeUrl: String, regenerateUrl: String }

  connect() {
    this.dragging = false

    if (this.hasAudioTarget) {
      this.wireAudioEvents()
    }

    if (this.autoplayValue && this.hasAudioTarget) {
      setTimeout(() => this.audioTarget.play().catch(() => {}), 100)
    }
  }

  toggle() {
    if (!this.hasAudioTarget) {
      if (this.synthesizing) return
      this.synthesize()
      return
    }

    if (this.audioTarget.paused) {
      this.audioTarget.play().catch(() => {})
    } else {
      this.audioTarget.pause()
    }
  }

  async synthesize() {
    this.synthesizing = true
    this.element.classList.add("is-loading")

    try {
      const response = await fetch(this.synthesizeUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.error || "Speech synthesis failed")
      }

      const { url } = await response.json()

      // Build the full player UI
      const audio = document.createElement("audio")
      audio.src = url
      audio.preload = "metadata"
      audio.dataset.audioPlayerTarget = "audio"
      this.element.appendChild(audio)

      // Add wave, track, and time elements
      this.element.insertAdjacentHTML("beforeend", `
        <div class="audio-player-wave" data-audio-player-target="wave">
          <span></span><span></span><span></span><span></span><span></span>
        </div>
        <div class="audio-player-track" data-audio-player-target="progress">
          <div class="audio-player-fill" data-audio-player-target="fill"></div>
        </div>
        <span class="audio-player-time" data-audio-player-target="time">0:00</span>
      `)

      this.element.classList.remove("audio-player-synthesize")
      this.wireAudioEvents()

      audio.play().catch(() => {})
    } catch (e) {
      console.error("Speech synthesis error:", e)
      this.element.title = e.message
    } finally {
      this.synthesizing = false
      this.element.classList.remove("is-loading")
    }
  }

  async regenerate() {
    if (this.regenerating) return
    this.regenerating = true
    this.element.classList.add("is-loading")

    // Stop current playback
    if (this.hasAudioTarget) {
      this.audioTarget.pause()
      this.audioTarget.currentTime = 0
    }

    try {
      const response = await fetch(this.regenerateUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.error || "Regeneration failed")
      }

      const { url } = await response.json()
      this.audioTarget.src = url
      this.audioTarget.load()
      if (this.hasFillTarget) this.fillTarget.style.width = "0%"
    } catch (e) {
      console.error("Audio regeneration error:", e)
      this.element.title = e.message
    } finally {
      this.regenerating = false
      this.element.classList.remove("is-loading")
    }
  }

  wireAudioEvents() {
    const audio = this.audioTarget

    audio.addEventListener("loadedmetadata", () => this.updateTime())
    audio.addEventListener("timeupdate", () => {
      if (!this.dragging) this.updateProgress()
      this.updateTime()
    })
    audio.addEventListener("ended", () => this.onEnded())
    audio.addEventListener("play", () => this.onPlay())
    audio.addEventListener("pause", () => this.onPause())

    if (this.hasProgressTarget) {
      this.progressTarget.addEventListener("pointerdown", (e) => this.startScrub(e))
    }
  }

  onPlay() {
    this.element.classList.add("is-playing", "has-played")
    this.animateWave(true)
  }

  onPause() {
    this.element.classList.remove("is-playing")
    this.animateWave(false)
  }

  onEnded() {
    this.element.classList.remove("is-playing", "has-played")
    this.animateWave(false)
    if (this.hasFillTarget) this.fillTarget.style.width = "0%"
  }

  updateProgress() {
    if (!this.hasAudioTarget || !this.hasFillTarget) return
    const { currentTime, duration } = this.audioTarget
    if (!duration) return
    const pct = (currentTime / duration) * 100
    this.fillTarget.style.width = `${pct}%`
  }

  updateTime() {
    if (!this.hasAudioTarget || !this.hasTimeTarget) return
    const { currentTime, duration } = this.audioTarget
    if (!duration || !isFinite(duration)) {
      this.timeTarget.textContent = "0:00"
      return
    }
    const remaining = duration - currentTime
    this.timeTarget.textContent = this.formatTime(remaining)
  }

  startScrub(e) {
    this.dragging = true
    this.scrub(e)

    const onMove = (ev) => this.scrub(ev)
    const onUp = () => {
      this.dragging = false
      document.removeEventListener("pointermove", onMove)
      document.removeEventListener("pointerup", onUp)
    }

    document.addEventListener("pointermove", onMove)
    document.addEventListener("pointerup", onUp)
  }

  scrub(e) {
    if (!this.hasProgressTarget || !this.hasFillTarget) return
    const rect = this.progressTarget.getBoundingClientRect()
    const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
    this.fillTarget.style.width = `${pct * 100}%`
    if (this.hasAudioTarget && this.audioTarget.duration) {
      this.audioTarget.currentTime = pct * this.audioTarget.duration
    }
  }

  animateWave(playing) {
    if (!this.hasWaveTarget) return
    const bars = this.waveTarget.children
    for (let i = 0; i < bars.length; i++) {
      bars[i].style.animationPlayState = playing ? "running" : "paused"
    }
  }

  formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, "0")}`
  }
}
