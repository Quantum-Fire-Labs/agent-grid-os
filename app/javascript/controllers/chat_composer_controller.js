import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "send", "stop"]
  static values = { haltUrl: String }

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
      this.toggleStopButton()
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

  halt() {
    if (!this.haltUrlValue) return

    // Remove streaming UI immediately so the user sees feedback,
    // even though the LLM HTTP call is still in-flight server-side.
    // Turbo silently ignores updates to targets that no longer exist,
    // so subsequent streaming tokens become no-ops on the client.
    document.getElementById("typing-indicator")?.remove()
    document.querySelectorAll("[id^='streaming-message-']").forEach(el => el.remove())
    this.toggleStopButton()

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.haltUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token, "Accept": "text/html" }
    })
  }

  toggleStopButton() {
    if (!this.hasSendTarget || !this.hasStopTarget) return
    const typing = document.getElementById("typing-indicator")
    const streaming = document.querySelector("[id^='streaming-message-']")
    const active = !!(typing || streaming)
    this.sendTarget.style.display = active ? "none" : ""
    this.stopTarget.style.display = active ? "" : "none"
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
