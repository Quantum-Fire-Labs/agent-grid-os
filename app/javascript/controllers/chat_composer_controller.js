import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.autoResize()
    this.scrollToBottom()

    this.observer = new MutationObserver((mutations) => {
      // Only scroll for content changes — ignore audio player state toggles
      const relevant = mutations.some(m =>
        m.type === "childList" ||
        m.type === "characterData" ||
        (m.type === "attributes" && !m.target.closest(".audio-player, .audio-player-fill"))
      )
      if (relevant && this.isNearBottom()) this.scrollToBottom()
    })
    const messages = document.getElementById("chat-messages")
    if (messages) {
      this.observer.observe(messages, { childList: true, subtree: true, characterData: true })
    }

    document.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    this.observer?.disconnect()
    document.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  handleSubmitEnd = (event) => {
    if (event.detail.success && this.element.contains(event.detail.formSubmission.formElement)) {
      this.inputTarget.value = ""
      this.autoResize()
      this.inputTarget.focus()
    }
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.inputTarget.value.trim()) {
        this.unlockAudio()
        this.element.requestSubmit()
      }
    }
  }

  // Called on any form submit to unlock audio playback for the session.
  // Browser autoplay policy requires a user gesture to enable audio —
  // this creates + resumes an AudioContext during the gesture so that
  // later .play() calls (from TTS via Turbo Stream) are allowed.
  unlockAudio() {
    if (window._audioContext) return
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    ctx.resume()
    window._audioContext = ctx
  }

  autoResize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = Math.min(input.scrollHeight, 160) + "px"
  }

  isNearBottom() {
    const thread = document.getElementById("chat-thread")
    if (!thread) return true
    return thread.scrollHeight - thread.scrollTop - thread.clientHeight < 150
  }

  scrollToBottom() {
    const thread = document.getElementById("chat-thread")
    if (thread) {
      thread.scrollTop = thread.scrollHeight
    }
  }
}
