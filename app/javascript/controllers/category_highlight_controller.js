import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  highlight(event) {
    let noteId = event.target.dataset.noteId
    this.element.querySelectorAll(".note").forEach((element) => {
      element.classList.remove("bg-shade")
    })
    this.element.querySelectorAll(`div[data-note-id="${noteId}"]`).forEach((element) => {
      element.classList.add("bg-shade")
    })
  }
}
