import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel"]
  static values = { url: String }

  connect() {
    this.loading = false
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) this.loadOlder()
      },
      { root: this.element, rootMargin: "200px 0px 0px 0px" }
    )
    if (this.hasSentinelTarget) {
      this.observer.observe(this.sentinelTarget)
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  sentinelTargetConnected(el) {
    this.observer?.observe(el)
  }

  sentinelTargetDisconnected(el) {
    this.observer?.unobserve(el)
  }

  async loadOlder() {
    if (this.loading) return
    this.loading = true

    const sentinel = this.sentinelTarget
    const messages = document.getElementById("chat-messages")
    const firstMsg = messages.querySelector(".chat-msg")

    if (!firstMsg?.dataset.createdAt) {
      this.loading = false
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("before", firstMsg.dataset.createdAt)

    try {
      const response = await fetch(url, {
        headers: { "Accept": "text/html" }
      })
      if (!response.ok) return

      const html = await response.text()
      if (!html.trim()) return

      sentinel.remove()

      const scrollBottom = this.element.scrollHeight - this.element.scrollTop
      messages.insertAdjacentHTML("afterbegin", html)
      this.element.scrollTop = this.element.scrollHeight - scrollBottom
    } finally {
      this.loading = false
    }
  }
}
