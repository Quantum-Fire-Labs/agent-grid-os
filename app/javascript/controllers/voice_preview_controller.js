import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  toggle(event) {
    event.preventDefault()

    // Stop any other playing previews
    document.querySelectorAll("[data-controller='voice-preview'].playing").forEach(el => {
      if (el !== this.element) {
        this.application.getControllerForElementAndIdentifier(el, "voice-preview")?.stop()
      }
    })

    if (this.audio && !this.audio.paused) {
      this.stop()
    } else {
      this.play()
    }
  }

  play() {
    this.audio = new Audio(this.urlValue)
    this.element.classList.add("playing")
    this.audio.addEventListener("ended", () => this.stop())
    this.audio.play().catch(() => this.stop())
  }

  stop() {
    if (this.audio) {
      this.audio.pause()
      this.audio = null
    }
    this.element.classList.remove("playing")
  }

  disconnect() {
    this.stop()
  }
}
