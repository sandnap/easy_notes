import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="history"
export default class extends Controller {
  connect() {
    this.history = []
    this.viewingNoteId = null
  }

  add(event) {
    const noteId = event.target.dataset.noteId
    if (!this.navigating && this.viewingNoteId !== noteId) {
      // Only keep 5 iterms in history
      this.history = this.history.slice(-4)
      this.history.push(noteId)
      this.viewingNoteId = noteId
    }
    this.navigating = false
  }

  back() {
    const idx = this.history.lastIndexOf(this.viewingNoteId)
    const noteId = this.history[idx - 1]
    this.navigating = true
    if (noteId) {
      this.viewingNoteId = noteId
      const note = document.querySelector(`a[data-note-id='${noteId}']`)
      note.click()
      this.highlight(noteId)
    }
  }

  forward() {
    const idx = this.history.lastIndexOf(this.viewingNoteId)
    const noteId = this.history[idx + 1]
    this.navigating = true
    if (noteId) {
      this.viewingNoteId = noteId
      const note = document.querySelector(`a[data-note-id='${noteId}']`)
      this.highlight(noteId)
      note.click()
    }
  }

  hasHistory() {
    return this.history.length > 0
  }

  highlight(noteId) {
    this.element.querySelectorAll(".note").forEach((element) => {
      element.classList.remove("bg-shade")
    })
    this.element.querySelectorAll(`div[data-note-id="${noteId}"]`).forEach((element) => {
      element.classList.add("bg-shade")
    })
  }
}
