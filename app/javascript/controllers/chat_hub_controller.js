import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "panel", "search", "list", "conversation"]
  static values = { hasConversation: Boolean }

  connect() {
    this.mobileBreakpoint = 768

    // On mobile, if a conversation is loaded via URL, show the panel
    if (this.hasConversationValue && window.innerWidth < this.mobileBreakpoint) {
      this.element.classList.add("chat-hub-show-panel")
    }
  }

  selectConversation(event) {
    // On mobile, slide to chat panel
    if (window.innerWidth < this.mobileBreakpoint) {
      this.element.classList.add("chat-hub-show-panel")
    }
  }

  showSidebar(event) {
    event.preventDefault()
    this.element.classList.remove("chat-hub-show-panel")

    // On mobile, navigate back to /chats (no conversation selected)
    if (window.innerWidth < this.mobileBreakpoint) {
      history.pushState({}, "", "/chats")
    }
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim()
    this.conversationTargets.forEach(el => {
      const name = el.dataset.name || ""
      el.style.display = name.includes(query) ? "" : "none"
    })
  }
}
