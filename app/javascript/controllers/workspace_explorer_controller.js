import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tree", "viewer", "viewerContent", "viewerFilename", "newInput"]
  static values = { agentId: Number }

  connect() {
    this.loadDirectory(".", this.treeTarget)
  }

  async loadDirectory(path, container) {
    const url = `/agents/${this.agentIdValue}/workspace.json?path=${encodeURIComponent(path)}`
    const response = await fetch(url, { headers: { "Accept": "application/json" } })
    const entries = await response.json()

    container.innerHTML = ""

    if (entries.length === 0) {
      container.innerHTML = '<div class="workspace-empty-dir">Empty directory</div>'
      return
    }

    const sorted = entries.sort((a, b) => {
      if (a.type !== b.type) return a.type === "directory" ? -1 : 1
      return a.name.localeCompare(b.name)
    })

    sorted.forEach(entry => {
      const row = document.createElement("div")
      row.className = `workspace-entry workspace-entry-${entry.type}`
      row.dataset.path = path === "." ? entry.name : `${path}/${entry.name}`
      row.dataset.type = entry.type

      const icon = entry.type === "directory" ? this.folderIcon() : this.fileIcon()
      const size = entry.type === "file" ? `<span class="workspace-entry-size">${this.formatSize(entry.size)}</span>` : ""

      row.innerHTML = `
        <span class="workspace-entry-icon">${icon}</span>
        <span class="workspace-entry-name">${this.escapeHtml(entry.name)}</span>
        ${size}
      `

      if (entry.type === "directory") {
        row.addEventListener("click", (e) => this.toggleDirectory(e, row))
      } else {
        row.addEventListener("click", () => this.viewFile(row.dataset.path))
      }

      container.appendChild(row)

      if (entry.type === "directory") {
        const children = document.createElement("div")
        children.className = "workspace-children"
        children.style.display = "none"
        container.appendChild(children)
      }
    })
  }

  async toggleDirectory(event, row) {
    event.stopPropagation()
    const children = row.nextElementSibling
    if (!children) return

    if (children.style.display === "none") {
      if (children.children.length === 0) {
        await this.loadDirectory(row.dataset.path, children)
      }
      children.style.display = "block"
      row.classList.add("workspace-entry-open")
    } else {
      children.style.display = "none"
      row.classList.remove("workspace-entry-open")
    }
  }

  async viewFile(path) {
    const url = `/agents/${this.agentIdValue}/workspace.json?path=${encodeURIComponent(path)}&file=1`
    const response = await fetch(url, { headers: { "Accept": "application/json" } })
    const data = await response.json()

    if (this.hasViewerTarget) {
      this.viewerTarget.style.display = "block"
      this.viewerFilenameTarget.textContent = path
      this.viewerContentTarget.textContent = data.content || "(empty file)"
    }
  }

  closeViewer() {
    if (this.hasViewerTarget) {
      this.viewerTarget.style.display = "none"
    }
  }

  showNewInput(event) {
    const type = event.params.type
    if (this.hasNewInputTarget) {
      this.newInputTarget.style.display = "flex"
      this.newInputTarget.dataset.entryType = type
      const input = this.newInputTarget.querySelector("input")
      input.placeholder = type === "directory" ? "Directory name" : "File name"
      input.value = ""
      input.focus()
    }
  }

  async submitNew(event) {
    event.preventDefault()
    const input = this.newInputTarget.querySelector("input")
    const name = input.value.trim()
    if (!name) return

    const type = this.newInputTarget.dataset.entryType || "file"
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    await fetch(`/agents/${this.agentIdValue}/workspace`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ entry: { name, type, path: "." } })
    })

    this.newInputTarget.style.display = "none"
    input.value = ""
    await this.loadDirectory(".", this.treeTarget)
  }

  cancelNew() {
    if (this.hasNewInputTarget) {
      this.newInputTarget.style.display = "none"
    }
  }

  folderIcon() {
    return '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2 4c0-.55.45-1 1-1h3.59l1.7 1.71c.19.18.44.29.71.29h4c.55 0 1 .45 1 1v6c0 .55-.45 1-1 1H3c-.55 0-1-.45-1-1V4z" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round"/></svg>'
  }

  fileIcon() {
    return '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M4 2h5l3 3v8c0 .55-.45 1-1 1H4c-.55 0-1-.45-1-1V3c0-.55.45-1 1-1z" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 2v3h3" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round"/></svg>'
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / 1048576).toFixed(1)} MB`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
