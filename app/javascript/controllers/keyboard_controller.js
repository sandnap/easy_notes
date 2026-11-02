import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === "s") {
      event.preventDefault()
      this.submitTarget.click()
    }
  }
}
