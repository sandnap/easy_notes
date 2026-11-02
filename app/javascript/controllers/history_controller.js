import { Controller } from "@hotwired/stimulus"

// Remembers notes opened in this tab. sessionStorage survives the full page
// loads and Turbo body replacements that happen while moving between notes.
const HISTORY_LIMIT = 5
const STORAGE_KEY = "easy_notes.note_history"

function readStore() {
  try {
    const parsed = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "")
    if (parsed && Array.isArray(parsed.history) && Number.isInteger(parsed.index)) return parsed
  } catch {
    // A missing or unreadable value starts a new history.
  }

  return { history: [], index: -1 }
}

function writeStore(store) {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(store))
}

export default class extends Controller {
  connect() {
    this.navigating = false
    this.#syncButtons()
  }

  add() {
    if (!this.navigating) return

    this.navigating = false
    this.#syncButtons()
  }

  remember(noteId) {
    noteId = noteId?.toString()
    if (!noteId) return

    if (this.navigating) {
      this.navigating = false
      this.#syncButtons()
      return
    }

    const store = readStore()
    if (store.history[store.index] === noteId) {
      this.#syncButtons()
      return
    }

    store.history = store.history.slice(0, store.index + 1)
    store.history.push(noteId)
    if (store.history.length > HISTORY_LIMIT) store.history = store.history.slice(-HISTORY_LIMIT)
    store.index = store.history.length - 1
    writeStore(store)
    this.#syncButtons()
  }

  back(event) {
    event?.preventDefault()
    const store = readStore()
    if (store.index <= 0) return

    store.index -= 1
    writeStore(store)
    this.#open(store.history[store.index])
  }

  forward(event) {
    event?.preventDefault()
    const store = readStore()
    if (store.index < 0 || store.index >= store.history.length - 1) return

    store.index += 1
    writeStore(store)
    this.#open(store.history[store.index])
  }

  highlight(noteId) {
    this.element.querySelectorAll(".note").forEach((element) => {
      element.classList.remove("bg-shade")
    })
    this.element.querySelectorAll(`div[data-note-id="${noteId}"]`).forEach((element) => {
      element.classList.add("bg-shade")
    })
  }

  #open(noteId) {
    const note = document.querySelector(`#sidebar a[data-note-id='${noteId}']`)
      || document.querySelector(`a[data-note-id='${noteId}']`)

    if (!note) return

    this.navigating = true
    note.click()
    this.highlight(noteId)
    this.#syncButtons()
  }

  #syncButtons() {
    const store = readStore()
    document.querySelectorAll("[data-action='click->history#back']").forEach((button) => {
      button.disabled = store.index <= 0
    })
    document.querySelectorAll("[data-action='click->history#forward']").forEach((button) => {
      button.disabled = store.index < 0 || store.index >= store.history.length - 1
    })
  }
}
