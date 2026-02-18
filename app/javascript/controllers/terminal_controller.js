import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { Terminal } from "xterm"
import { FitAddon } from "xterm-addon-fit"

export default class extends Controller {
  static targets = ["container"]
  static values = { agentId: Number, command: String }

  connect() {
    this.terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "'JetBrains Mono', 'Courier New', monospace",
      theme: {
        background: "#0a0a0a",
        foreground: "#e0e0e0",
        cursor: "#e0e0e0"
      }
    })

    this.fitAddon = new FitAddon()
    this.terminal.loadAddon(this.fitAddon)
    this.terminal.open(this.containerTarget)
    this.fitAddon.fit()

    this.resizeObserver = new ResizeObserver(() => {
      this.fitAddon.fit()
      this.sendResize()
    })
    this.resizeObserver.observe(this.containerTarget)

    this.terminal.onData((data) => {
      this.subscription?.send({ input: data })
    })

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: "WorkspaceTerminalChannel",
        agent_id: this.agentIdValue,
        command: this.commandValue || undefined,
        cols: this.terminal.cols,
        rows: this.terminal.rows
      },
      {
        received: (data) => this.received(data),
        rejected: () => {
          this.terminal.writeln("\r\n--- Connection rejected — workspace may not be running. ---")
        }
      }
    )
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
    this.terminal?.dispose()
  }

  received(data) {
    if (data.event === "exit") {
      this.terminal.writeln("\r\n--- Session ended. ---")
      return
    }
    if (data.output) {
      this.terminal.write(data.output)
    }
  }

  sendResize() {
    this.subscription?.send({ resize: { cols: this.terminal.cols, rows: this.terminal.rows } })
  }
}
