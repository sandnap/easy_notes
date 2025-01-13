import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="category-highlight"
export default class extends Controller {
  highlight(event) {
    let noteId = event.target.dataset.noteId
    this.element.querySelectorAll(".note").forEach((element) => {
      element.classList.remove("bg-shade")
    })
    this.element.querySelector(`[data-note-id="${noteId}"]`).classList.add("bg-shade")
  }
}
