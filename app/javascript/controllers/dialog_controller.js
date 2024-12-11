import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  showModal() {
    this.menuTarget.showModal()
  }

  close(event) {
    if (event?.detail?.success) {
      // Only close if the form submission was successful
      this.menuTarget.close()
    } else if (!event || !event.detail || event.detail === 1) {
      // Close normally for non-form-submission cases
      this.menuTarget.close()
    }
  }

  closeOnClickOutside({ target }) {
    target.nodeName === "DIALOG" && this.close()
  }

  disconnect() {
    if (this.menuTarget && this.menuTarget.open) {
      this.close()
    }
  }
}
