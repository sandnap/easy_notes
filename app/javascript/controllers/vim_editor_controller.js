import { Controller } from "@hotwired/stimulus"
import {
  lineBoundsAt,
  clampToLine,
  moveHorizontal,
  firstNonBlankOnLine,
  moveVertical,
  wordForward,
  wordBackward,
  wordEnd,
  fullLineDeleteRange
} from "lib/vim_motions"

const STORAGE_KEY = "easy_notes.vim_mode"

export default class extends Controller {
  static targets = ["badge", "toggleButton", "submit"]

  connect() {
    this.isMobile = this.#detectMobile()
    this.enabled = !this.isMobile && window.localStorage.getItem(STORAGE_KEY) === "true"
    this.mode = "normal"
    this.pendingKey = ""
    this.commandBuffer = null
    this.preferredColumn = null
    this.register = { text: "", linewise: false }

    this.boundKeydown = this.#onKeydown.bind(this)
    this.boundTrixInit = this.#onTrixInitialize.bind(this)

    this.element.addEventListener("trix-initialize", this.boundTrixInit)
    this.element.addEventListener("keydown", this.boundKeydown, true)

    this.#syncUI()
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.boundTrixInit)
    this.element.removeEventListener("keydown", this.boundKeydown, true)
  }

  toggle() {
    if (this.isMobile) return

    this.enabled = !this.enabled
    window.localStorage.setItem(STORAGE_KEY, this.enabled ? "true" : "false")
    this.mode = "normal"
    this.pendingKey = ""
    this.commandBuffer = null
    this.preferredColumn = null
    this.#syncUI()
    this.trixElement?.focus()
  }

  get trixElement() {
    return this.element.querySelector("trix-editor")
  }

  get editor() {
    return this.trixElement?.editor
  }

  #detectMobile() {
    const coarse = window.matchMedia && window.matchMedia("(pointer: coarse)").matches
    const narrow = window.innerWidth > 0 && window.innerWidth < 768
    return Boolean(coarse || narrow)
  }

  #onTrixInitialize() {
    if (this.enabled) {
      this.mode = "normal"
    }
    this.#syncUI()
  }

  #syncUI() {
    const trix = this.trixElement
    if (this.isMobile) {
      if (this.hasToggleButtonTarget) this.toggleButtonTarget.classList.add("hidden")
      if (this.hasBadgeTarget) this.badgeTarget.classList.add("hidden")
      trix?.setAttribute("data-vim-mode", "off")
      return
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.classList.remove("hidden")
      this.toggleButtonTarget.textContent = this.enabled ? "Vim: On" : "Vim: Off"
      this.toggleButtonTarget.setAttribute("aria-pressed", this.enabled ? "true" : "false")
    }

    this.element.setAttribute("data-vim-ready", "true")

    if (this.hasBadgeTarget) {
      if (!this.enabled) {
        this.badgeTarget.classList.add("hidden")
        this.badgeTarget.textContent = ""
      } else {
        this.badgeTarget.classList.remove("hidden")
        if (this.commandBuffer !== null) {
          this.badgeTarget.textContent = `:${this.commandBuffer}`
        } else if (this.pendingKey) {
          this.badgeTarget.textContent = `NORMAL (${this.pendingKey})`
        } else {
          this.badgeTarget.textContent = this.mode.toUpperCase()
        }
      }
    }

    if (trix) {
      trix.setAttribute("data-vim-mode", this.enabled ? this.mode : "off")
    }
  }

  #editableText() {
    const raw = this.editor?.getDocument()?.toString() ?? ""
    return raw.endsWith("\n") ? raw.slice(0, -1) : raw
  }

  #cursorOffset() {
    const range = this.editor?.getSelectedRange()
    return range ? range[0] : 0
  }

  #mutateRange(range, replacement = "") {
    this.editor.recordUndoEntry("Vim edit")
    this.editor.setSelectedRange(range)
    this.editor.insertString(replacement)
  }

  #setCursor(offset, keepPreferredColumn = false) {
    const text = this.#editableText()
    const maxOffset = Math.max(0, text.length)
    const clamped = Math.max(0, Math.min(offset, maxOffset))
    this.editor?.setSelectedRange([clamped, clamped])
    if (!keepPreferredColumn) {
      this.preferredColumn = null
    }
  }

  #enterInsertMode(targetOffset = null) {
    if (targetOffset !== null) {
      this.#setCursor(targetOffset)
    }
    this.mode = "insert"
    this.pendingKey = ""
    this.commandBuffer = null
    this.#syncUI()
  }

  #enterNormalMode(stepBack = false) {
    if (stepBack && this.editor) {
      const text = this.#editableText()
      const pos = this.#cursorOffset()
      const { start } = lineBoundsAt(text, pos)
      const nextPos = pos > start ? clampToLine(text, pos - 1) : start
      this.#setCursor(nextPos)
    }
    this.mode = "normal"
    this.pendingKey = ""
    this.commandBuffer = null
    this.#syncUI()
  }

  #onKeydown(event) {
    if (!this.enabled || this.isMobile) return
    const trix = this.trixElement
    if (!trix || !this.editor) return
    if (event.target !== trix && !trix.contains(event.target)) return

    if (this.mode === "insert") {
      if (event.key === "Escape") {
        event.preventDefault()
        event.stopPropagation()
        this.#enterNormalMode(true)
      }
      return
    }

    // Normal mode handling
    if (event.metaKey || event.altKey) return

    // Handle Ctrl+r (redo) in Normal mode; allow Ctrl+s to pass through
    if (event.ctrlKey) {
      if (event.key === "r") {
        event.preventDefault()
        event.stopPropagation()
        this.editor.redo()
      }
      return
    }

    // Ignore lone modifier keys
    if (["Shift", "Control", "Alt", "Meta", "CapsLock"].includes(event.key)) {
      return
    }

    // Ex-command buffer (:w)
    if (this.commandBuffer !== null) {
      event.preventDefault()
      event.stopPropagation()

      if (event.key === "Escape") {
        this.commandBuffer = null
        this.#syncUI()
        return
      }
      if (event.key === "Backspace") {
        if (this.commandBuffer.length === 0) {
          this.commandBuffer = null
        } else {
          this.commandBuffer = this.commandBuffer.slice(0, -1)
        }
        this.#syncUI()
        return
      }
      if (event.key === "Enter") {
        const cmd = this.commandBuffer.trim()
        this.commandBuffer = null
        this.#syncUI()
        if (cmd === "w" || cmd === "write") {
          this.#triggerSave()
        }
        return
      }
      if (event.key.length === 1) {
        this.commandBuffer += event.key
        this.#syncUI()
      }
      return
    }

    event.preventDefault()
    event.stopPropagation()

    if (event.key === "Escape") {
      this.pendingKey = ""
      this.preferredColumn = null
      this.#syncUI()
      return
    }

    if (this.pendingKey) {
      const chord = this.pendingKey + event.key
      this.pendingKey = ""
      this.#handleChord(chord)
      this.#syncUI()
      return
    }

    this.#handleNormalKey(event.key)
    this.#syncUI()
  }

  #handleChord(chord) {
    const text = this.#editableText()
    const pos = this.#cursorOffset()

    switch (chord) {
      case "gg": {
        this.#setCursor(0)
        break
      }
      case "dd": {
        if (text.length === 0) break
        const { range, lineText } = fullLineDeleteRange(text, pos)
        this.register = { text: lineText, linewise: true }
        this.#mutateRange(range, "")
        const updated = this.#editableText()
        const target = Math.min(range[0], Math.max(0, updated.length - 1))
        const { start } = lineBoundsAt(updated, target)
        this.#setCursor(start)
        break
      }
      case "dw": {
        if (text.length === 0) break
        const end = wordForward(text, pos, true)
        if (end > pos) {
          this.register = { text: text.slice(pos, end), linewise: false }
          this.#mutateRange([pos, end], "")
          this.#setCursor(pos)
        }
        break
      }
      case "yy": {
        const { start, end } = lineBoundsAt(text, pos)
        this.register = { text: text.slice(start, end), linewise: true }
        break
      }
      case "yw": {
        const end = wordForward(text, pos, true)
        this.register = { text: text.slice(pos, end), linewise: false }
        break
      }
      default:
        break
    }
  }

  #handleNormalKey(key) {
    const text = this.#editableText()
    const pos = this.#cursorOffset()
    const { start, end } = lineBoundsAt(text, pos)

    switch (key) {
      // Pending operators / prefixes
      case "d":
      case "y":
      case "g":
        this.pendingKey = key
        break

      // Ex-command mode
      case ":":
        this.commandBuffer = ""
        break

      // Mode transitions to Insert
      case "i":
        this.#enterInsertMode(clampToLine(text, pos))
        break
      case "a": {
        const afterPos = end > start ? Math.min(end, pos + 1) : start
        this.#enterInsertMode(afterPos)
        break
      }
      case "I":
        this.#enterInsertMode(firstNonBlankOnLine(text, pos))
        break
      case "A":
        this.#enterInsertMode(end)
        break
      case "o": {
        this.#mutateRange([end, end], "\n")
        this.#enterInsertMode(end + 1)
        break
      }
      case "O": {
        this.#mutateRange([start, start], "\n")
        this.#enterInsertMode(start)
        break
      }

      // Horizontal motions
      case "h":
      case "ArrowLeft":
      case "Backspace":
        this.#setCursor(moveHorizontal(text, pos, -1))
        break
      case "l":
      case "ArrowRight":
      case " ":
        this.#setCursor(moveHorizontal(text, pos, 1))
        break
      case "0":
        this.#setCursor(start)
        break
      case "^":
        this.#setCursor(firstNonBlankOnLine(text, pos))
        break
      case "$":
        this.#setCursor(end > start ? end - 1 : start)
        break

      // Vertical motions
      case "j":
      case "ArrowDown": {
        const next = moveVertical(text, pos, 1, this.preferredColumn)
        this.preferredColumn = next.col
        this.#setCursor(next.offset, true)
        break
      }
      case "k":
      case "ArrowUp": {
        const prev = moveVertical(text, pos, -1, this.preferredColumn)
        this.preferredColumn = prev.col
        this.#setCursor(prev.offset, true)
        break
      }

      // Word motions
      case "w":
        this.#setCursor(wordForward(text, pos, false))
        break
      case "b":
        this.#setCursor(wordBackward(text, pos))
        break
      case "e":
        this.#setCursor(wordEnd(text, pos))
        break

      // Document end
      case "G": {
        if (text.length === 0) {
          this.#setCursor(0)
        } else {
          const lastBounds = lineBoundsAt(text, text.length - 1)
          this.#setCursor(lastBounds.start)
        }
        break
      }

      // Single-key deletions
      case "x": {
        if (end > start && pos < end) {
          const delPos = clampToLine(text, pos)
          this.register = { text: text[delPos] || "", linewise: false }
          this.#mutateRange([delPos, delPos + 1], "")
          const updated = this.#editableText()
          this.#setCursor(clampToLine(updated, delPos))
        }
        break
      }
      case "D": {
        if (end > pos) {
          this.register = { text: text.slice(pos, end), linewise: false }
          this.#mutateRange([pos, end], "")
          const updated = this.#editableText()
          this.#setCursor(clampToLine(updated, Math.max(start, pos - 1)))
        }
        break
      }

      // Paste
      case "p": {
        if (!this.register.text && !this.register.linewise) break
        if (this.register.linewise) {
          this.#mutateRange([end, end], "\n" + this.register.text)
          this.#setCursor(end + 1)
        } else {
          const insertAt = end > start ? Math.min(end, pos + 1) : start
          this.#mutateRange([insertAt, insertAt], this.register.text)
          const landAt = insertAt + Math.max(0, this.register.text.length - 1)
          this.#setCursor(landAt)
        }
        break
      }
      case "P": {
        if (!this.register.text && !this.register.linewise) break
        if (this.register.linewise) {
          this.#mutateRange([start, start], this.register.text + "\n")
          this.#setCursor(start)
        } else {
          this.#mutateRange([pos, pos], this.register.text)
          const landAt = pos + Math.max(0, this.register.text.length - 1)
          this.#setCursor(landAt)
        }
        break
      }

      // Undo
      case "u":
        this.editor.undo()
        break

      default:
        break
    }
  }

  #triggerSave() {
    if (this.hasSubmitTarget) {
      this.submitTarget.click()
    } else {
      const form = this.element.querySelector("form")
      form?.requestSubmit()
    }
  }
}
