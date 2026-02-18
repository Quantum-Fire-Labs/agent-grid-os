import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recordButton", "ttsToggle", "ttsField", "audioField"]

  connect() {
    this.recording = false
    this.mediaRecorder = null
    this.chunks = []
    this.ttsEnabled = false
    this.updateTtsField()
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.ctrlKey && event.code === "Space") {
      event.preventDefault()
      this.toggleRecord()
    }
  }

  async toggleRecord() {
    if (this.recording) {
      this.stopRecording()
    } else {
      await this.startRecording()
    }
  }

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream, { mimeType: this.supportedMimeType() })
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) this.chunks.push(e.data)
      }

      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach(t => t.stop())
        this.handleRecordingComplete()
      }

      this.mediaRecorder.start()
      this.recording = true
      this.recordButtonTarget.classList.add("recording")
    } catch (err) {
      console.error("Microphone access denied:", err)
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop()
    }
    this.recording = false
    this.recordButtonTarget.classList.remove("recording")
  }

  handleRecordingComplete() {
    const mimeType = this.mediaRecorder.mimeType
    const ext = mimeType.includes("webm") ? "webm" : "mp4"
    const blob = new Blob(this.chunks, { type: mimeType })

    const form = this.element.closest("form")
    const formData = new FormData(form)
    formData.set("message[audio]", blob, `voice.${ext}`)
    formData.set("tts", "1")

    fetch(form.action, {
      method: "POST",
      body: formData,
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      }
    }).then(response => response.text()).then(html => {
      Turbo.renderStreamMessage(html)
    })
  }

  toggleTts() {
    this.ttsEnabled = !this.ttsEnabled
    this.updateTtsField()
    this.ttsToggleTarget.classList.toggle("active", this.ttsEnabled)
  }

  updateTtsField() {
    this.ttsFieldTarget.value = this.ttsEnabled ? "1" : "0"
    if (this.hasTtsToggleTarget) {
      this.ttsToggleTarget.classList.toggle("active", this.ttsEnabled)
    }
  }

  supportedMimeType() {
    const types = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"]
    return types.find(t => MediaRecorder.isTypeSupported(t)) || ""
  }
}
