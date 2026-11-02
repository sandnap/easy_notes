import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "preview", "editButton", "previewButton"]
  static values = { url: String }

  connect() {
    this.requestId = 0
    this.#setMode("edit")
  }

  showEdit(event) {
    event?.preventDefault()
    this.requestId += 1
    this.#setMode("edit")
  }

  async showPreview(event) {
    event?.preventDefault()
    const requestId = ++this.requestId
    const content = this.editorTarget.value
    this.#setMode("preview")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "text/html"
        },
        body: new URLSearchParams({ content })
      })
      if (requestId !== this.requestId) return

      if (!response.ok) {
        this.previewTarget.textContent = "Preview failed."
        return
      }

      this.previewTarget.innerHTML = await response.text()
    } catch {
      if (requestId !== this.requestId) return
      this.previewTarget.textContent = "Preview failed."
    }
  }

  #setMode(mode) {
    const previewing = mode === "preview"
    this.editorTarget.hidden = previewing
    this.previewTarget.hidden = !previewing
    this.editButtonTarget.setAttribute("aria-pressed", previewing ? "false" : "true")
    this.previewButtonTarget.setAttribute("aria-pressed", previewing ? "true" : "false")

    if (previewing) {
      this.element.setAttribute("data-vim-suspended", "true")
      this.editorTarget.blur()
    } else {
      this.element.removeAttribute("data-vim-suspended")
      this.editorTarget.focus()
    }
  }
}
