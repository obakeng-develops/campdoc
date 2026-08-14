import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    const token = new URLSearchParams(window.location.hash.slice(1)).get("token")
    if (!token) return

    this.inputTarget.value = token
    this.submitTarget.disabled = false
    history.replaceState(null, "", `${window.location.pathname}${window.location.search}`)
  }
}
