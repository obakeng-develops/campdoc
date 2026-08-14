import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "prompt", "state", "submit", "zone"]

  choose(event) {
    if (event.target === this.inputTarget) return
    if (event.target.closest(".selected-file__remove")) return
    if (this.zoneTarget.dataset.hasFiles === "true" && !event.target.closest(".change-files")) return
    event.preventDefault()
    if (event.target.closest(".change-files")) event.stopPropagation()
    this.inputTarget.click()
  }

  dragOver(event) {
    event.preventDefault()
    this.zoneTarget.dataset.dragging = "true"
  }

  dragLeave() {
    delete this.zoneTarget.dataset.dragging
  }

  drop(event) {
    event.preventDefault()
    delete this.zoneTarget.dataset.dragging
    this.inputTarget.files = event.dataTransfer.files
    this.render()
  }

  changed() {
    this.render()
  }

  remove(event) {
    event.stopPropagation()
    const index = Number(event.currentTarget.dataset.index)
    const transfer = new DataTransfer()
    Array.from(this.inputTarget.files).forEach((file, fileIndex) => {
      if (fileIndex !== index) transfer.items.add(file)
    })
    this.inputTarget.files = transfer.files
    this.render()
  }

  uploadProgress(event) {
    this.submitTarget.disabled = true
    this.submitTarget.value = `Sending… ${Math.round(event.detail.progress)}%`
  }

  uploadEnd() {
    this.submitTarget.disabled = false
    this.submitTarget.value = "Send files"
  }

  render() {
    const files = Array.from(this.inputTarget.files)
    this.listTarget.replaceChildren(...files.map((file, index) => this.fileRow(file, index)))
    this.stateTarget.hidden = files.length === 0
    this.promptTarget.hidden = files.length > 0
    this.zoneTarget.dataset.hasFiles = files.length > 0
    if (files.length === 0) {
      this.zoneTarget.setAttribute("tabindex", "0")
      this.zoneTarget.setAttribute("role", "button")
      this.zoneTarget.setAttribute("aria-label", "Choose files to send")
    } else {
      this.zoneTarget.removeAttribute("tabindex")
      this.zoneTarget.removeAttribute("role")
      this.zoneTarget.removeAttribute("aria-label")
    }
  }

  fileRow(file, index) {
    const row = document.createElement("div")
    row.className = "selected-file"

    const preview = document.createElement("div")
    preview.className = "selected-file__preview"
    if (file.type.startsWith("image/")) {
      const image = document.createElement("img")
      image.src = URL.createObjectURL(file)
      image.alt = ""
      image.onload = () => URL.revokeObjectURL(image.src)
      preview.append(image)
    } else {
      preview.classList.add("selected-file__preview--document")
      const extension = file.name.includes(".") ? file.name.split(".").pop().toUpperCase() : "FILE"
      preview.textContent = extension
    }

    const details = document.createElement("div")
    details.className = "selected-file__details"
    const name = document.createElement("strong")
    name.textContent = file.name
    const size = document.createElement("span")
    size.textContent = this.humanSize(file.size)
    details.append(name, size)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "selected-file__remove"
    remove.dataset.index = index
    remove.dataset.action = "file-drop#remove"
    remove.setAttribute("aria-label", `Remove ${file.name}`)
    remove.textContent = "×"

    row.append(preview, details, remove)
    return row
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`
    return `${(bytes / 1024 ** 3).toFixed(1)} GB`
  }
}
