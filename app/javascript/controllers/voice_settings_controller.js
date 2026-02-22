import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["speedValue", "whisperModel"]

  submitForm() {
    this.element.requestSubmit()
  }

  updateSpeed(event) {
    this.speedValueTarget.textContent = parseFloat(event.target.value).toFixed(2)
  }

  toggleWhisperModel(event) {
    this.whisperModelTarget.hidden = event.target.value !== "local"
  }

  preview(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const url = btn.dataset.previewUrl
    if (!url) return

    if (this._audio) {
      this._audio.pause()
      this._audio = null
      this.element.querySelectorAll(".voice-preview-btn.playing").forEach(b => b.classList.remove("playing"))
    }

    this._audio = new Audio(url)
    btn.classList.add("playing")
    this._audio.addEventListener("ended", () => btn.classList.remove("playing"))
    this._audio.play()
  }
}
