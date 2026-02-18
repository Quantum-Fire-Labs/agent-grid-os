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
}
