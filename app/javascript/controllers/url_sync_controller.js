import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    noteId: String,
    categoryId: String
  }

  connect() {
    this.#syncBrowserUrl()
    this.#syncSidebarHighlight()
    this.#rememberNote()
  }

  #syncBrowserUrl() {
    if (!this.hasUrlValue || !this.urlValue) return

    const currentPath = window.location.pathname
    // If we are already on this URL or on the equivalent /categories/:cid/notes/:id/edit URL, keep it
    if (currentPath === this.urlValue) return
    if (this.hasNoteIdValue && this.noteIdValue && currentPath.endsWith(`/notes/${this.noteIdValue}/edit`)) {
      window.history.replaceState({ turbo: true, url: this.urlValue }, "", this.urlValue)
      return
    }

    window.history.pushState({ turbo: true, url: this.urlValue }, "", this.urlValue)
  }

  #rememberNote() {
    if (!this.hasNoteIdValue || !this.noteIdValue) return

    const history = this.application.getControllerForElementAndIdentifier(document.body, "history")
    history?.remember(this.noteIdValue)
  }

  #syncSidebarHighlight() {
    const allNotes = document.querySelectorAll(".note")
    allNotes.forEach((el) => el.classList.remove("bg-shade"))

    if (this.hasNoteIdValue && this.noteIdValue) {
      document.querySelectorAll(`div.note[data-note-id="${this.noteIdValue}"]`).forEach((el) => {
        el.classList.add("bg-shade")
      })
    }

    if (this.hasCategoryIdValue && this.categoryIdValue) {
      document.querySelectorAll(`details.category_${this.categoryIdValue}`).forEach((details) => {
        details.open = true
      })
    }
  }
}
