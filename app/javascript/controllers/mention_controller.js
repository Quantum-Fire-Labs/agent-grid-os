import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { names: Array }

  connect() {
    this.selectedIndex = -1
    this.dropdown = null
    this.selecting = false
  }

  disconnect() {
    this.removeDropdown()
  }

  onInput() {
    if (this.selecting) return

    const { query, start } = this.mentionQuery()
    if (query === null) {
      this.removeDropdown()
      return
    }

    const matches = this.namesValue.filter(name =>
      name.toLowerCase().startsWith(query.toLowerCase())
    )

    if (matches.length === 0) {
      this.removeDropdown()
      return
    }

    this.mentionStart = start
    this.matches = matches
    this.selectedIndex = 0
    this.renderDropdown()
  }

  onKeydown(event) {
    if (!this.dropdown) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        event.stopImmediatePropagation()
        this.selectedIndex = (this.selectedIndex + 1) % this.matches.length
        this.renderDropdown()
        break
      case "ArrowUp":
        event.preventDefault()
        event.stopImmediatePropagation()
        this.selectedIndex = (this.selectedIndex - 1 + this.matches.length) % this.matches.length
        this.renderDropdown()
        break
      case "Enter":
      case "Tab":
        event.preventDefault()
        event.stopImmediatePropagation()
        this.selectMention(this.matches[this.selectedIndex])
        break
      case "Escape":
        event.preventDefault()
        event.stopImmediatePropagation()
        this.removeDropdown()
        break
    }
  }

  mentionQuery() {
    const input = this.inputTarget
    const cursor = input.selectionStart
    const text = input.value.substring(0, cursor)
    const match = text.match(/@(\w*)$/)

    if (!match) return { query: null, start: null }

    return { query: match[1], start: cursor - match[0].length }
  }

  selectMention(name) {
    this.selecting = true
    const input = this.inputTarget
    const before = input.value.substring(0, this.mentionStart)
    const after = input.value.substring(input.selectionStart)
    input.value = `${before}@${name} ${after}`
    const newCursor = this.mentionStart + name.length + 2
    input.setSelectionRange(newCursor, newCursor)
    this.removeDropdown()
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.selecting = false
  }

  renderDropdown() {
    if (this.dropdown) {
      this.dropdown.remove()
      this.dropdown = null
    }

    this.dropdown = document.createElement("div")
    this.dropdown.className = "mention-dropdown"

    this.matches.forEach((name, index) => {
      const item = document.createElement("div")
      item.className = "mention-dropdown-item"
      if (index === this.selectedIndex) item.classList.add("active")
      item.textContent = `@${name}`
      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        this.selectMention(name)
      })
      this.dropdown.appendChild(item)
    })

    const inner = this.inputTarget.closest(".chat-composer-inner")
    if (inner) {
      inner.appendChild(this.dropdown)
    }
  }

  removeDropdown() {
    if (this.dropdown) {
      this.dropdown.remove()
      this.dropdown = null
    }
    this.selectedIndex = -1
  }
}
