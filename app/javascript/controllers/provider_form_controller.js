import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["apiKeySection", "oauthSection", "nameSelect", "oauthStatus", "oauthActions", "modelSelect", "modelText", "designation"]
  static values = { connected: Boolean }

  connect() {
    this.pollTimer = null
    this.previousDesignation = this.designationTarget.value
    this.nameChanged()
  }

  disconnect() {
    this.stopPolling()
  }

  nameChanged() {
    const name = this.nameSelectTarget.value
    const isOauth = name === "chatgpt"

    this.apiKeySectionTarget.hidden = isOauth
    this.oauthSectionTarget.hidden = !isOauth

    this.fetchModels(name)
  }

  designationChanged() {
    const value = this.designationTarget.value
    if (value === "default" && this.previousDesignation !== "default") {
      if (!confirm("Setting this provider as default will demote any existing default provider to fallback. Continue?")) {
        this.designationTarget.value = this.previousDesignation
        return
      }
    }
    this.previousDesignation = value
  }

  async fetchModels(providerName) {
    const currentModel = this.modelTextTarget.value || this.modelSelectTarget.value

    try {
      const response = await fetch(`/settings/provider_models?provider_name=${encodeURIComponent(providerName)}`)
      if (!response.ok) throw new Error("Failed to fetch models")

      const models = await response.json()

      if (models.length === 0) {
        this.showTextInput(currentModel)
        return
      }

      this.showSelectInput(models, currentModel)
    } catch {
      this.showTextInput(currentModel)
    }
  }

  showTextInput(value) {
    this.modelSelectTarget.hidden = true
    this.modelSelectTarget.name = ""
    this.modelTextTarget.hidden = false
    this.modelTextTarget.name = "provider[model]"
    if (value) this.modelTextTarget.value = value
  }

  showSelectInput(models, currentModel) {
    const select = this.modelSelectTarget
    select.innerHTML = ""

    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select a model..."
    select.appendChild(blank)

    let currentFound = false
    models.forEach(m => {
      const option = document.createElement("option")
      option.value = m.id
      option.textContent = m.name
      if (m.id === currentModel) {
        option.selected = true
        currentFound = true
      }
      select.appendChild(option)
    })

    const other = document.createElement("option")
    other.value = "__other__"
    other.textContent = "Other..."
    select.appendChild(other)

    select.hidden = false
    select.name = "provider[model]"
    this.modelTextTarget.hidden = true
    this.modelTextTarget.name = ""

    if (currentModel && !currentFound) {
      select.value = "__other__"
      this.switchToTextInput(currentModel)
    }
  }

  modelSelectChanged() {
    if (this.modelSelectTarget.value === "__other__") {
      this.switchToTextInput("")
    }
  }

  switchToTextInput(value) {
    this.modelSelectTarget.hidden = true
    this.modelSelectTarget.name = ""
    this.modelTextTarget.hidden = false
    this.modelTextTarget.name = "provider[model]"
    this.modelTextTarget.value = value
    this.modelTextTarget.focus()
  }

  async startOauth(event) {
    event.preventDefault()
    const name = this.nameSelectTarget.value

    try {
      const response = await fetch(`/settings/oauth_connections`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ provider_name: name })
      })

      if (!response.ok) throw new Error("Failed to start OAuth")

      const data = await response.json()
      this.deviceCode = data.device_code
      this.userCode = data.user_code

      this.oauthStatusTarget.innerHTML = `
        <p>Visit <a href="${data.verification_uri}" target="_blank" rel="noopener">${data.verification_uri}</a></p>
        <p>Enter code: <strong>${data.user_code}</strong></p>
        <p class="form-hint">Waiting for authorization...</p>
      `

      this.startPolling(name, data.device_code, data.user_code, data.interval || 5)
    } catch (error) {
      this.oauthStatusTarget.innerHTML = `<p class="text-danger">${error.message}</p>`
    }
  }

  startPolling(name, deviceCode, userCode, interval) {
    this.stopPolling()
    this.pollTimer = setInterval(() => this.poll(name, deviceCode, userCode), interval * 1000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async poll(name, deviceCode, userCode) {
    try {
      const response = await fetch(`/settings/oauth_connections/${name}?device_code=${deviceCode}&user_code=${userCode}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      if (!response.ok) throw new Error("Polling failed")

      const data = await response.json()

      if (data.status === "connected") {
        this.stopPolling()
        this.connectedValue = true
        this.oauthStatusTarget.innerHTML = `<p class="text-success">Connected</p>`
        this.oauthActionsTarget.innerHTML = `
          <button type="button" class="btn btn-ghost btn-sm text-danger" data-action="provider-form#disconnectOauth">Disconnect</button>
        `
      }
    } catch (error) {
      this.stopPolling()
      this.oauthStatusTarget.innerHTML = `<p class="text-danger">${error.message}</p>`
    }
  }

  async disconnectOauth(event) {
    event.preventDefault()
    const name = this.nameSelectTarget.value

    try {
      const response = await fetch(`/settings/oauth_connections/${name}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      if (response.redirected) {
        window.location.href = response.url
        return
      }

      this.connectedValue = false
      this.oauthStatusTarget.innerHTML = ""
      this.oauthActionsTarget.innerHTML = `
        <button type="button" class="btn btn-primary btn-sm" data-action="provider-form#startOauth">Connect</button>
      `
    } catch (error) {
      this.oauthStatusTarget.innerHTML = `<p class="text-danger">${error.message}</p>`
    }
  }
}
