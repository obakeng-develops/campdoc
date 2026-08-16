import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.file"
let pickerPromise
let identityPromise

export default class extends Controller {
  static targets = ["button", "error", "status"]
  static values = { apiKey: String, appId: String, clientId: String, url: String }

  async open() {
    this.busy("Opening Google Drive…")

    try {
      await Promise.all([this.loadPicker(), this.loadIdentity()])
      this.tokenClient ||= google.accounts.oauth2.initTokenClient({
        client_id: this.clientIdValue,
        scope: DRIVE_SCOPE,
        callback: (response) => this.authorized(response)
      })
      this.tokenClient.requestAccessToken({ prompt: "" })
    } catch (_error) {
      this.showError("Google Drive couldn't open. Check your connection and try again.")
    }
  }

  authorized(response) {
    if (response.error) {
      this.showError("Google Drive access wasn't granted.")
      return
    }

    this.accessToken = response.access_token
    const view = new google.picker.DocsView(google.picker.ViewId.DOCS)
      .setIncludeFolders(false)
      .setSelectFolderEnabled(false)
      .setMode(google.picker.DocsViewMode.LIST)

    const picker = new google.picker.PickerBuilder()
      .addView(view)
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
      .setDeveloperKey(this.apiKeyValue)
      .setAppId(this.appIdValue)
      .setOAuthToken(this.accessToken)
      .setCallback((data) => this.picked(data))
      .build()

    picker.setVisible(true)
    this.statusTarget.textContent = "Choose up to 20 files."
  }

  async picked(data) {
    if (data.action === google.picker.Action.CANCEL) {
      this.reset()
      return
    }
    if (data.action !== google.picker.Action.PICKED) return

    const files = data.docs.map((file) => ({
      id: file.id,
      name: file.name,
      resource_key: file.resourceKey
    }))
    this.busy(`Starting ${files.length} ${files.length === 1 ? "import" : "imports"}…`)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
        },
        body: JSON.stringify({ files, access_token: this.accessToken })
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error)

      this.accessToken = null
      Turbo.visit(result.redirect_url)
    } catch (error) {
      this.showError(error.message || "Google Drive couldn't start the import.")
    }
  }

  loadPicker() {
    pickerPromise ||= this.loadScript("https://apis.google.com/js/api.js").then(() =>
      new Promise((resolve) => gapi.load("picker", resolve))
    )
    return pickerPromise
  }

  loadIdentity() {
    identityPromise ||= this.loadScript("https://accounts.google.com/gsi/client")
    return identityPromise
  }

  loadScript(src) {
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src="${src}"]`)
      if (existing) {
        if (existing.dataset.loaded) resolve()
        else {
          existing.addEventListener("load", resolve, { once: true })
          existing.addEventListener("error", reject, { once: true })
        }
        return
      }

      const script = document.createElement("script")
      script.src = src
      script.async = true
      script.addEventListener("load", () => {
        script.dataset.loaded = "true"
        resolve()
      }, { once: true })
      script.addEventListener("error", reject, { once: true })
      document.head.appendChild(script)
    })
  }

  busy(message) {
    this.errorTarget.hidden = true
    this.buttonTarget.disabled = true
    this.statusTarget.textContent = message
  }

  reset() {
    this.buttonTarget.disabled = false
    this.statusTarget.textContent = "Campdoc saves a private copy."
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.reset()
  }
}
