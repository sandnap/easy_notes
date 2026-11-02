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
const MIRROR_PROPERTIES = [
  "boxSizing",
  "borderTopWidth",
  "borderRightWidth",
  "borderBottomWidth",
  "borderLeftWidth",
  "paddingTop",
  "paddingRight",
  "paddingBottom",
  "paddingLeft",
  "fontStyle",
  "fontVariant",
  "fontWeight",
  "fontStretch",
  "fontSize",
  "lineHeight",
  "fontFamily",
  "textAlign",
  "textTransform",
  "textIndent",
  "letterSpacing",
  "wordSpacing",
  "tabSize"
]

export default class extends Controller {
  static targets = ["badge", "toggleButton", "submit", "input"]

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
    this.undoStack = []
    this.redoStack = []
    this.insertSnapshot = null

    this.boundKeydown = this.#onKeydown.bind(this)
    this.boundCursorUpdate = this.#updateBlockCursor.bind(this)

    this.element.addEventListener("focusin", this.boundCursorUpdate)
    this.element.addEventListener("focusout", this.boundCursorUpdate)
    this.element.addEventListener("click", this.boundCursorUpdate)
    this.textarea?.addEventListener("scroll", this.boundCursorUpdate)
    this.textarea?.addEventListener("input", this.boundCursorUpdate)
    window.addEventListener("keydown", this.boundKeydown, true)
    window.addEventListener("resize", this.boundCursorUpdate)
    window.addEventListener("scroll", this.boundCursorUpdate, true)

    this.#ensureBlockCursorElement()
    this.#syncUI()
    if (this.textarea) this.#activateEditorOnLoad()
  }

  disconnect() {
    this.element.removeEventListener("focusin", this.boundCursorUpdate)
    this.element.removeEventListener("focusout", this.boundCursorUpdate)
    this.element.removeEventListener("click", this.boundCursorUpdate)
    this.textarea?.removeEventListener("scroll", this.boundCursorUpdate)
    this.textarea?.removeEventListener("input", this.boundCursorUpdate)
    window.removeEventListener("keydown", this.boundKeydown, true)
    window.removeEventListener("resize", this.boundCursorUpdate)
    window.removeEventListener("scroll", this.boundCursorUpdate, true)
    this.blockCursorEl?.remove()
    this.blockCursorEl = null
    this.mirrorEl?.remove()
    this.mirrorEl = null
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
    this.textarea?.focus()
  }

  get textarea() {
    return this.hasInputTarget ? this.inputTarget : null
  }

  #detectMobile() {
    const coarse = window.matchMedia && window.matchMedia("(pointer: coarse)").matches
    const narrow = window.innerWidth > 0 && window.innerWidth < 768
    return Boolean(coarse || narrow)
  }

  #suspended() {
    return this.element.hasAttribute("data-vim-suspended")
  }

  #activateEditorOnLoad() {
    if (!this.enabled || this.isMobile || this.#suspended()) return
    const textarea = this.textarea
    if (!textarea) return

    const active = document.activeElement
    const isTypingInOtherInput = active && active !== textarea &&
      (active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.isContentEditable)

    if (!isTypingInOtherInput) {
      textarea.focus()
      if (textarea.selectionStart == null) textarea.setSelectionRange(0, 0)
    }
  }

  #syncUI() {
    const textarea = this.textarea
    if (this.isMobile) {
      if (this.hasToggleButtonTarget) this.toggleButtonTarget.classList.add("hidden")
      if (this.hasBadgeTarget) this.badgeTarget.hidden = true
      textarea?.setAttribute("data-vim-mode", "off")
      return
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.classList.remove("hidden")
      this.toggleButtonTarget.textContent = this.enabled ? "Vim: On" : "Vim: Off"
      this.toggleButtonTarget.setAttribute("aria-pressed", this.enabled ? "true" : "false")
    }

    this.element.setAttribute("data-vim-ready", "true")

    if (this.hasBadgeTarget) {
      this.badgeTarget.hidden = !this.enabled
      if (!this.enabled) {
        this.badgeTarget.textContent = ""
      } else {
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

    if (textarea) {
      textarea.setAttribute("data-vim-mode", this.enabled ? this.mode : "off")
    }
    this.#updateBlockCursor()
  }

  #ensureBlockCursorElement() {
    if (this.blockCursorEl) return
    const el = document.createElement("div")
    el.className = "vim-block-cursor hidden"
    el.style.display = "none"
    el.setAttribute("aria-hidden", "true")
    this.element.appendChild(el)
    this.blockCursorEl = el
  }

  #mirrorElement() {
    if (this.mirrorEl) return this.mirrorEl
    const el = document.createElement("div")
    el.setAttribute("aria-hidden", "true")
    document.body.appendChild(el)
    this.mirrorEl = el
    return el
  }

  #caretRect() {
    const textarea = this.textarea
    const style = window.getComputedStyle(textarea)
    const mirror = this.#mirrorElement()
    MIRROR_PROPERTIES.forEach((prop) => {
      mirror.style[prop] = style[prop]
    })
    mirror.style.position = "absolute"
    mirror.style.visibility = "hidden"
    mirror.style.whiteSpace = "pre-wrap"
    mirror.style.wordWrap = "break-word"
    mirror.style.overflow = "hidden"
    mirror.style.height = "auto"
    mirror.style.top = "0"
    mirror.style.left = "0"
    mirror.style.width = `${textarea.offsetWidth}px`

    const pos = this.#cursorOffset()
    mirror.replaceChildren(document.createTextNode(textarea.value.slice(0, pos)))
    const marker = document.createElement("span")
    marker.textContent = "\u200b"
    mirror.appendChild(marker)

    const textareaRect = textarea.getBoundingClientRect()
    const mirrorRect = mirror.getBoundingClientRect()
    const markerRect = marker.getBoundingClientRect()
    const lineHeight = parseFloat(style.lineHeight) || 22
    return {
      left: textareaRect.left + (markerRect.left - mirrorRect.left) - textarea.scrollLeft,
      top: textareaRect.top + (markerRect.top - mirrorRect.top) - textarea.scrollTop,
      height: markerRect.height || lineHeight
    }
  }

  #updateBlockCursor() {
    this.#ensureBlockCursorElement()
    const textarea = this.textarea
    const hide = !this.blockCursorEl || !textarea || !this.enabled || this.isMobile || this.mode !== "normal" || this.#suspended()
    if (hide) {
      if (this.blockCursorEl) {
        this.blockCursorEl.classList.add("hidden")
        this.blockCursorEl.style.display = "none"
      }
      return
    }

    let rect
    try {
      rect = this.#caretRect()
    } catch {
      rect = null
    }

    if (!rect || (rect.height === 0 && rect.top === 0 && rect.left === 0)) {
      const textareaRect = textarea.getBoundingClientRect()
      const style = window.getComputedStyle(textarea)
      const padLeft = parseFloat(style.paddingLeft) || 0
      const padTop = parseFloat(style.paddingTop) || 0
      const lineHeight = parseFloat(style.lineHeight) || 22
      rect = {
        left: textareaRect.left + padLeft,
        top: textareaRect.top + padTop,
        height: lineHeight
      }
    }

    const computedFont = parseFloat(window.getComputedStyle(textarea).fontSize) || 16
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
    return this.textarea?.value ?? ""
  }

  #cursorOffset() {
    return this.textarea?.selectionStart ?? 0
  }

  #pushUndo() {
    this.undoStack.push({ value: this.textarea.value, cursor: this.#cursorOffset() })
    if (this.undoStack.length > 200) this.undoStack.shift()
    this.redoStack = []
  }

  #restore(state) {
    this.textarea.value = state.value
    this.#setCursor(state.cursor, true)
  }

  #undo() {
    if (!this.undoStack.length || !this.textarea) return
    this.redoStack.push({ value: this.textarea.value, cursor: this.#cursorOffset() })
    this.#restore(this.undoStack.pop())
  }

  #redo() {
    if (!this.redoStack.length || !this.textarea) return
    this.undoStack.push({ value: this.textarea.value, cursor: this.#cursorOffset() })
    this.#restore(this.redoStack.pop())
  }

  #mutateRange(range, replacement = "") {
    const textarea = this.textarea
    if (!textarea) return
    const value = textarea.value
    this.#pushUndo()
    const [start, end] = range
    textarea.value = value.slice(0, start) + replacement + value.slice(end)
  }

  #setCursor(offset, keepPreferredColumn = false) {
    const textarea = this.textarea
    if (!textarea) return
    const clamped = Math.max(0, Math.min(offset, textarea.value.length))
    textarea.setSelectionRange(clamped, clamped)
    if (!keepPreferredColumn) this.preferredColumn = null
  }

  #consumeCount() {
    if (!this.countBuffer) return null
    const parsed = parseInt(this.countBuffer, 10)
    this.countBuffer = ""
    return Number.isNaN(parsed) || parsed < 1 ? 1 : parsed
  }

  #enterInsertMode(targetOffset = null) {
    if (targetOffset !== null) this.#setCursor(targetOffset)
    this.insertSnapshot = { value: this.textarea.value, cursor: this.#cursorOffset() }
    this.mode = "insert"
    this.pendingKey = ""
    this.countBuffer = ""
    this.commandBuffer = null
    this.#syncUI()
  }

  #enterNormalMode(stepBack = false) {
    if (this.insertSnapshot && this.textarea && this.insertSnapshot.value !== this.textarea.value) {
      this.undoStack.push(this.insertSnapshot)
      this.redoStack = []
    }
    this.insertSnapshot = null

    if (stepBack && this.textarea) {
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
    if (!this.enabled || this.isMobile || this.#suspended()) return
    const textarea = this.textarea
    if (!textarea) return

    const target = event.target
    const insideEditor = target === textarea
    if (!insideEditor) {
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
      if (this.mode !== "normal") return
      textarea.focus()
    }

    if (this.mode === "insert") {
      if (event.key === "Escape") {
        event.preventDefault()
        event.stopPropagation()
        this.#enterNormalMode(true)
      }
      return
    }

    if (event.metaKey || event.altKey) return

    if (event.ctrlKey) {
      if (event.key === "r") {
        event.preventDefault()
        event.stopPropagation()
        this.#redo()
      }
      return
    }

    if (["Shift", "Control", "Alt", "Meta", "CapsLock"].includes(event.key)) return

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
      case ":":
        this.commandBuffer = ""
        break
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
      case "u":
        this.#undo()
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
