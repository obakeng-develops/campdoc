import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content },
      credentials: "same-origin"
    })
  }
}
