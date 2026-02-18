import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  switch(event) {
    const view = event.currentTarget.dataset.view
    const container = this.element.closest(".dashboard").querySelector(".agents-grid")

    this.element.querySelectorAll(".view-toggle-btn").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.view === view)
    })

    if (container) {
      container.classList.toggle("list-view", view === "list")
    }
  }
}
