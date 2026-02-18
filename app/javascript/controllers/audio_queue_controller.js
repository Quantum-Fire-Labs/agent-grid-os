import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chunk"]

  initialize() {
    this.queue = []
    this.playing = false
  }

  chunkTargetConnected(el) {
    this.queue.push(el.dataset.src)
    el.remove()
    this.playNext()
  }

  playNext() {
    if (this.playing || this.queue.length === 0) return

    this.playing = true
    const src = this.queue.shift()
    const audio = new Audio(src)

    audio.addEventListener("ended", () => {
      this.playing = false
      this.playNext()
    })

    audio.addEventListener("error", () => {
      this.playing = false
      this.playNext()
    })

    audio.play().catch(() => {
      this.playing = false
      this.playNext()
    })
  }
}
