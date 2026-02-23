import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customFields"]

  toggle() {
    const isCustom = this.element.querySelector("input[name=scope]:checked")?.value === "custom"
    this.customFieldsTarget.style.display = isCustom ? "" : "none"
  }
}
