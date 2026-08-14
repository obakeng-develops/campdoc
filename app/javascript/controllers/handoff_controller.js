import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.element.classList.add("is-pending")
    this.observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return

      this.element.classList.add("is-playing")
      this.observer.disconnect()
    }, { threshold: 0.35 })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
