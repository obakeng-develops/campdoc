import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "status", "submit"]
  static values = { finalText: String }

  connect() {
    this.originalText = this.submitTarget.value
    this.progress = new Map()
    this.failedUploads = new Set()
  }

  disconnect() {
    clearTimeout(this.slowTimer)
  }

  start(event) {
    this.totalUploads ||= [...this.element.querySelectorAll("input[type=file][data-direct-upload-url]")]
      .reduce((total, input) => total + input.files.length, 0)
    this.progress.set(event.detail.id, 0)
    this.errorTarget.hidden = true
    if (this.hasStatusTarget) {
      this.statusTarget.hidden = false
      this.statusTarget.textContent = "Uploading files…"
    }
    this.submitTarget.disabled = true
    this.slowTimer ||= setTimeout(() => {
      if (this.hasStatusTarget) this.statusTarget.textContent = "Still uploading. Large files can take a few minutes; keep this page open."
    }, 8000)
    this.update()
  }

  updateProgress(event) {
    this.progress.set(event.detail.id, event.detail.progress)
    this.update()
  }

  end(event) {
    if (this.failedUploads.delete(event.detail.id)) return

    this.progress.set(event.detail.id, 100)
    this.update()

    if ([...this.progress.values()].filter((value) => value === 100).length === this.totalUploads) {
      clearTimeout(this.slowTimer)
      this.slowTimer = null
      this.submitTarget.disabled = false
      this.submitTarget.value = this.hasFinalTextValue ? this.finalTextValue : this.originalText
      if (this.hasStatusTarget) this.statusTarget.textContent = "Upload complete. Saving files…"
    }
  }

  error(event) {
    event.preventDefault()
    this.failedUploads.add(event.detail.id)
    this.errorTarget.textContent = `We couldn’t upload ${event.detail.file.name}. ${event.detail.error} Choose the file and try again.`
    this.errorTarget.hidden = false
    clearTimeout(this.slowTimer)
    this.slowTimer = null
    if (this.hasStatusTarget) this.statusTarget.hidden = true
    this.submitTarget.disabled = false
    this.submitTarget.value = this.originalText
    this.progress.clear()
    this.totalUploads = null
  }

  update() {
    const values = [...this.progress.values()]
    const percentage = values.reduce((total, value) => total + value, 0) / values.length
    this.submitTarget.value = `Uploading… ${Math.round(percentage)}%`
  }
}
