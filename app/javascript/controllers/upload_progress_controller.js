import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "submit"]
  static values = { finalText: String }

  connect() {
    this.originalText = this.submitTarget.value
    this.progress = new Map()
  }

  start(event) {
    this.totalUploads ||= [...this.element.querySelectorAll("input[type=file][data-direct-upload-url]")]
      .reduce((total, input) => total + input.files.length, 0)
    this.progress.set(event.detail.id, 0)
    this.errorTarget.hidden = true
    this.submitTarget.disabled = true
    this.update()
  }

  updateProgress(event) {
    this.progress.set(event.detail.id, event.detail.progress)
    this.update()
  }

  end(event) {
    this.progress.set(event.detail.id, 100)
    this.update()

    if ([...this.progress.values()].filter((value) => value === 100).length === this.totalUploads) {
      this.submitTarget.disabled = false
      this.submitTarget.value = this.hasFinalTextValue ? this.finalTextValue : this.originalText
    }
  }

  error(event) {
    event.preventDefault()
    this.errorTarget.textContent = `${event.detail.file.name}: ${event.detail.error}`
    this.errorTarget.hidden = false
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
