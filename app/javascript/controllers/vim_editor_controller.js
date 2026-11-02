import { Controller } from "@hotwired/stimulus"
import {
  lineBoundsAt,
  clampToLine,
  moveHorizontal,
  firstNonBlankOnLine,
  moveVertical,
  lineStartForNumber,
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
    const savedPref = window.localStorage.getItem(STORAGE_KEY)
    this.enabled = !this.isMobile && (savedPref === null ? true : savedPref === "true")
    this.mode = "normal"
    this.pendingKey = ""
    this.countBuffer = ""
    this.commandBuffer = null
    this.preferredColumn = null
    this.register = { text: "", linewise: false }

    this.boundKeydown = this.#onKeydown.bind(this)
    this.boundTrixInit = this.#onTrixInitialize.bind(this)
    this.boundCursorUpdate = this.#updateBlockCursor.bind(this)

    this.element.addEventListener("trix-initialize", this.boundTrixInit)
    this.element.addEventListener("trix-selection-change", this.boundCursorUpdate)
    this.element.addEventListener("trix-change", this.boundCursorUpdate)
    this.element.addEventListener("focusin", this.boundCursorUpdate)
    this.element.addEventListener("focusout", this.boundCursorUpdate)
    this.element.addEventListener("click", this.boundCursorUpdate)
    window.addEventListener("keydown", this.boundKeydown, true)
    window.addEventListener("resize", this.boundCursorUpdate)
    window.addEventListener("scroll", this.boundCursorUpdate, true)

    this.#ensureBlockCursorElement()
    this.#syncUI()
    if (this.editor) {
      this.#activateEditorOnLoad()
    }
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.boundTrixInit)
    this.element.removeEventListener("trix-selection-change", this.boundCursorUpdate)
    this.element.removeEventListener("trix-change", this.boundCursorUpdate)
    this.element.removeEventListener("focusin", this.boundCursorUpdate)
    this.element.removeEventListener("focusout", this.boundCursorUpdate)
    this.element.removeEventListener("click", this.boundCursorUpdate)
    window.removeEventListener("keydown", this.boundKeydown, true)
    window.removeEventListener("resize", this.boundCursorUpdate)
    window.removeEventListener("scroll", this.boundCursorUpdate, true)
    this.blockCursorEl?.remove()
    this.blockCursorEl = null
  }

  toggle() {
    if (this.isMobile) return

    this.enabled = !this.enabled
    window.localStorage.setItem(STORAGE_KEY, this.enabled ? "true" : "false")
    this.mode = "normal"
    this.pendingKey = ""
    this.countBuffer = ""
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
    this.#activateEditorOnLoad()
    this.#syncUI()
  }

  #activateEditorOnLoad() {
    if (!this.enabled || this.isMobile) return
    const trix = this.trixElement
    if (!trix || !this.editor) return

    const active = document.activeElement
    const isTypingInOtherInput = active && active !== trix && !trix.contains(active) &&
      (active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.isContentEditable)

    if (!isTypingInOtherInput) {
      trix.focus()
      const range = this.editor.getSelectedRange()
      if (!range) {
        this.editor.setSelectedRange([0, 0])
      }
    }
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
        const prefix = `${this.countBuffer}${this.pendingKey}`
        if (this.commandBuffer !== null) {
          this.badgeTarget.textContent = `:${this.commandBuffer}`
        } else if (prefix) {
          this.badgeTarget.textContent = `NORMAL (${prefix})`
        } else {
          this.badgeTarget.textContent = this.mode.toUpperCase()
        }
      }
    }

    if (trix) {
      trix.setAttribute("data-vim-mode", this.enabled ? this.mode : "off")
    }
    this.#updateBlockCursor()
  }

  #ensureBlockCursorElement() {
    if (this.blockCursorEl) return
    const el = document.createElement("div")
    el.className = "vim-block-cursor hidden"
    el.style.display = "none"
    el.setAttribute("data-vim-editor-target", "blockCursor")
    el.setAttribute("aria-hidden", "true")
    this.element.appendChild(el)
    this.blockCursorEl = el
  }

  #updateBlockCursor() {
    this.#ensureBlockCursorElement()
    const trix = this.trixElement
    if (!this.blockCursorEl || !trix || !this.editor || !this.enabled || this.isMobile || this.mode !== "normal") {
      if (this.blockCursorEl) {
        this.blockCursorEl.classList.add("hidden")
        this.blockCursorEl.style.display = "none"
      }
      return
    }

    const pos = this.#cursorOffset()
    let rect = this.editor.getClientRectAtPosition(pos)
    if (!rect && pos > 0) {
      rect = this.editor.getClientRectAtPosition(pos - 1)
    }

    if (!rect || (rect.width === 0 && rect.height === 0 && rect.top === 0 && rect.left === 0)) {
      const trixRect = trix.getBoundingClientRect()
      const style = window.getComputedStyle(trix)
      const padLeft = parseFloat(style.paddingLeft) || 0
      const padTop = parseFloat(style.paddingTop) || 0
      const lineHeight = parseFloat(style.lineHeight) || 22
      rect = {
        left: trixRect.left + padLeft,
        top: trixRect.top + padTop,
        width: 9,
        height: lineHeight
      }
    }

    const computedFont = parseFloat(window.getComputedStyle(trix).fontSize) || 16
    const width = Math.max(8, Math.round(computedFont * 0.58))
    const height = Math.max(16, Math.round(rect.height || computedFont * 1.35))

    this.blockCursorEl.style.left = `${Math.round(rect.left)}px`
    this.blockCursorEl.style.top = `${Math.round(rect.top)}px`
    this.blockCursorEl.style.width = `${width}px`
    this.blockCursorEl.style.height = `${height}px`
    this.blockCursorEl.classList.remove("hidden")
    this.blockCursorEl.style.display = "block"
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

  #consumeCount() {
    if (!this.countBuffer) return null
    const parsed = parseInt(this.countBuffer, 10)
    this.countBuffer = ""
    return Number.isNaN(parsed) || parsed < 1 ? 1 : parsed
  }

  #enterInsertMode(targetOffset = null) {
    if (targetOffset !== null) {
      this.#setCursor(targetOffset)
    }
    this.mode = "insert"
    this.pendingKey = ""
    this.countBuffer = ""
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
    this.countBuffer = ""
    this.commandBuffer = null
    this.#syncUI()
  }

  #onKeydown(event) {
    if (!this.enabled || this.isMobile) return
    const trix = this.trixElement
    if (!trix || !this.editor) return

    const target = event.target
    const insideTrix = target === trix || trix.contains(target)
    if (!insideTrix) {
      // Allow typing in the Note title input, sidebar search input, or dialogs undisturbed
      if (
        target &&
        (target.tagName === "INPUT" ||
          target.tagName === "TEXTAREA" ||
          target.tagName === "SELECT" ||
          target.isContentEditable ||
          target.closest("dialog[open]"))
      ) {
        return
      }
      // If we are in Normal mode and focus is on document.body / a non-input element,
      // focus trix-editor and handle the Normal-mode key immediately.
      if (this.mode !== "normal") return
      trix.focus()
    }

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

    // Ex-command buffer (:w or :<line>)
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
        } else if (/^\d+$/.test(cmd)) {
          const text = this.#editableText()
          this.#setCursor(lineStartForNumber(text, parseInt(cmd, 10)))
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
      this.countBuffer = ""
      this.preferredColumn = null
      this.#syncUI()
      return
    }

    // Numeric count prefix (1-9 to start, 0-9 to continue; bare 0 is line-start motion)
    if (!this.pendingKey && /^[0-9]$/.test(event.key)) {
      if (event.key !== "0" || this.countBuffer.length > 0) {
        this.countBuffer += event.key
        this.#syncUI()
        return
      }
    }

    if (this.pendingKey) {
      const chord = this.pendingKey + event.key
      this.pendingKey = ""
      const count = this.#consumeCount()
      this.#handleChord(chord, count)
      this.#syncUI()
      return
    }

    this.#handleNormalKey(event.key)
    this.#syncUI()
  }

  #handleChord(chord, count = null) {
    const text = this.#editableText()
    const pos = this.#cursorOffset()

    switch (chord) {
      case "gg": {
        const targetLine = count ?? 1
        this.#setCursor(lineStartForNumber(text, targetLine))
        break
      }
      case "dd": {
        if (text.length === 0) break
        const { range, lineText } = fullLineDeleteRange(text, pos)
        this.register = { text: lineText, linewise: true }
        this.#mutateRange(range, "")
        const updated = this.#editableText()
        const target = Math.min(range[0], Math.max(0, updated.length))
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
    // Keep countBuffer across operator/chord prefixes ('d', 'y', 'g')
    if (key === "d" || key === "y" || key === "g") {
      this.pendingKey = key
      return
    }

    const count = this.#consumeCount()
    const repeat = count ?? 1
    const text = this.#editableText()
    const pos = this.#cursorOffset()
    const { start, end } = lineBoundsAt(text, pos)

    switch (key) {
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
        this.#setCursor(moveHorizontal(text, pos, -repeat))
        break
      case "l":
      case "ArrowRight":
      case " ":
        this.#setCursor(moveHorizontal(text, pos, repeat))
        break
      case "0":
        this.#setCursor(start)
        break
      case "^":
        this.#setCursor(firstNonBlankOnLine(text, pos))
        break
      case "$":
        this.#setCursor(end)
        break

      // Vertical motions
      case "j":
      case "ArrowDown": {
        let cur = pos
        let col = this.preferredColumn
        for (let i = 0; i < repeat; i++) {
          const next = moveVertical(text, cur, 1, col)
          cur = next.offset
          col = next.col
        }
        this.preferredColumn = col
        this.#setCursor(cur, true)
        break
      }
      case "k":
      case "ArrowUp": {
        let cur = pos
        let col = this.preferredColumn
        for (let i = 0; i < repeat; i++) {
          const prev = moveVertical(text, cur, -1, col)
          cur = prev.offset
          col = prev.col
        }
        this.preferredColumn = col
        this.#setCursor(cur, true)
        break
      }

      // Word motions
      case "w": {
        let cur = pos
        for (let i = 0; i < repeat; i++) cur = wordForward(text, cur, false)
        this.#setCursor(cur)
        break
      }
      case "b": {
        let cur = pos
        for (let i = 0; i < repeat; i++) cur = wordBackward(text, cur)
        this.#setCursor(cur)
        break
      }
      case "e": {
        let cur = pos
        for (let i = 0; i < repeat; i++) cur = wordEnd(text, cur)
        this.#setCursor(cur)
        break
      }

      // Go to line <count>G or last line (G)
      case "G": {
        if (text.length === 0) {
          this.#setCursor(0)
        } else if (count !== null) {
          this.#setCursor(lineStartForNumber(text, count))
        } else {
          const lastBounds = lineBoundsAt(text, text.length)
          this.#setCursor(lastBounds.start)
        }
        break
      }

      // Single-key deletions
      case "x": {
        if (end > start) {
          const delPos = pos < end ? pos : end - 1
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
          this.#setCursor(clampToLine(updated, pos))
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
