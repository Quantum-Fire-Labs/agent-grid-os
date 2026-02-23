import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "panel", "search", "list", "chat"]
  static values = { hasChat: Boolean }

  connect() {
    this.mobileBreakpoint = 768

    // On mobile, if a chat is loaded via URL, show the panel
    if (this.hasChatValue && window.innerWidth < this.mobileBreakpoint) {
      this.element.classList.add("chat-hub-show-panel")
    }
  }

  selectChat(event) {
    // On mobile, slide to chat panel
    if (window.innerWidth < this.mobileBreakpoint) {
      this.element.classList.add("chat-hub-show-panel")
    }
  }

  showSidebar(event) {
    event.preventDefault()
    this.element.classList.remove("chat-hub-show-panel")

    // On mobile, navigate back to /chats (no chat selected)
    if (window.innerWidth < this.mobileBreakpoint) {
      history.pushState({}, "", "/chats")
    }
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim()
    this.chatTargets.forEach(el => {
      const name = el.dataset.name || ""
      el.style.display = name.includes(query) ? "" : "none"
    })
  }
}
