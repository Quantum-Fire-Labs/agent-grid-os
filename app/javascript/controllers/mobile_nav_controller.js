import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay"]

  toggle() {
    const isOpen = this.element.classList.toggle("nav-open")
    document.body.style.overflow = isOpen ? "hidden" : ""
  }

  close() {
    this.element.classList.remove("nav-open")
    document.body.style.overflow = ""
  }

  // Close on Escape key
  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
