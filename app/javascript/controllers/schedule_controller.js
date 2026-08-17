import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["local", "synced", "utc"]
  static values = { utc: String }

  connect() {
    if (!this.utcValue) return

    const date = new Date(this.utcValue)
    const pad = (value) => String(value).padStart(2, "0")
    this.localTarget.value = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
  }

  sync() {
    this.utcTarget.value = this.localTarget.value ? new Date(this.localTarget.value).toISOString() : ""
    this.syncedTarget.value = "1"
  }
}
