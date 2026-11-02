// Pure string/offset calculations for Vim motions on plain-text buffers.
// Callers pass the textarea value. A line's valid caret offsets span
// [start .. end] inclusive, where end is the offset after the last character.

export function lineBoundsAt(text, offset) {
  if (text.length === 0) return { start: 0, end: 0 }
  const clamped = Math.max(0, Math.min(offset, text.length))
  const prevNewline = clamped === 0 ? -1 : text.lastIndexOf("\n", clamped - 1)
  const start = prevNewline === -1 ? 0 : prevNewline + 1
  const nextNewline = text.indexOf("\n", start)
  const end = nextNewline === -1 ? text.length : nextNewline
  return { start, end }
}

export function clampToLine(text, offset) {
  const { start, end } = lineBoundsAt(text, offset)
  return Math.max(start, Math.min(offset, end))
}

export function moveHorizontal(text, offset, delta) {
  const { start, end } = lineBoundsAt(text, offset)
  return Math.max(start, Math.min(offset + delta, end))
}

export function firstNonBlankOnLine(text, offset) {
  const { start, end } = lineBoundsAt(text, offset)
  for (let i = start; i < end; i++) {
    if (text[i] !== " " && text[i] !== "\t") return i
  }
  return start
}

export function moveVertical(text, offset, direction, preferredColumn = null) {
  const { start, end } = lineBoundsAt(text, offset)
  const col = preferredColumn ?? Math.max(0, offset - start)

  if (direction < 0) {
    if (start === 0) return { offset, col }
    const prevEnd = start - 1
    const prevStart = prevEnd === 0 ? 0 : text.lastIndexOf("\n", prevEnd - 1) + 1
    const prevLen = Math.max(0, prevEnd - prevStart)
    const targetCol = Math.min(col, prevLen)
    return { offset: prevStart + targetCol, col }
  } else {
    if (end >= text.length) return { offset, col }
    const nextStart = end + 1
    const nextNewline = text.indexOf("\n", nextStart)
    const nextEnd = nextNewline === -1 ? text.length : nextNewline
    const nextLen = Math.max(0, nextEnd - nextStart)
    const targetCol = Math.min(col, nextLen)
    return { offset: nextStart + targetCol, col }
  }
}

export function lineStartForNumber(text, lineNumber) {
  if (text.length === 0 || lineNumber <= 1) return 0
  let currentLine = 1
  let idx = 0
  while (currentLine < lineNumber && idx <= text.length) {
    const nextNewline = text.indexOf("\n", idx)
    if (nextNewline === -1) {
      return idx
    }
    idx = nextNewline + 1
    currentLine++
  }
  return idx
}

function charClass(ch) {
  if (!ch) return "none"
  if (/\s/.test(ch)) return "space"
  if (/\w/.test(ch)) return "word"
  return "punct"
}

export function wordForward(text, offset, forDelete = false) {
  const len = text.length
  if (len === 0) return 0
  let i = Math.max(0, Math.min(offset, len - 1))
  const startClass = charClass(text[i])

  if (startClass !== "space") {
    while (i < len && charClass(text[i]) === startClass) i++
  }
  while (i < len && charClass(text[i]) === "space") {
    if (!forDelete && text[i] === "\n" && i > offset) {
      i++
      break
    }
    i++
  }
  return forDelete ? Math.min(len, i) : Math.min(Math.max(0, len - 1), i)
}

export function wordBackward(text, offset) {
  const len = text.length
  if (len === 0 || offset <= 0) return 0
  let i = Math.min(offset - 1, len - 1)

  while (i > 0 && charClass(text[i]) === "space") i--
  const targetClass = charClass(text[i])
  while (i > 0 && charClass(text[i - 1]) === targetClass) i--
  return i
}

// Next occurrence of char on the current line, starting after offset.
// A count that runs past the line leaves the cursor where it started.
export function findCharForward(text, offset, char, count = 1) {
  if (!char || char.length !== 1) return offset
  const { end } = lineBoundsAt(text, offset)
  const times = Number.isInteger(count) && count > 0 ? count : 1
  let from = Math.max(0, Math.min(offset, text.length))
  let found = from
  for (let n = 0; n < times; n++) {
    const idx = text.indexOf(char, from + 1)
    if (idx === -1 || idx >= end) return offset
    found = idx
    from = idx
  }
  return found
}

export function wordEnd(text, offset) {
  const len = text.length
  if (len === 0) return 0
  let i = Math.max(0, Math.min(offset + 1, len - 1))

  while (i < len && charClass(text[i]) === "space") i++
  const targetClass = charClass(text[i])
  while (i + 1 < len && charClass(text[i + 1]) === targetClass) i++
  return Math.min(Math.max(0, len - 1), i)
}

export function fullLineDeleteRange(text, offset) {
  const { start, end } = lineBoundsAt(text, offset)
  const lineText = text.slice(start, end)
  if (end < text.length && text[end] === "\n") {
    return { range: [start, end + 1], lineText }
  }
  if (start > 0 && text[start - 1] === "\n") {
    return { range: [start - 1, end], lineText }
  }
  return { range: [start, end], lineText }
}

// A caret sitting on a line's exclusive end (the offset `$` uses) has no
// character of its own. Character visual must not step past that offset.
function isEndCaret(text, offset) {
  return offset === lineBoundsAt(text, offset).end
}

// Half-open range for character or line visual mode. Line selections use the
// same newline rule as fullLineDeleteRange: the register text omits the
// boundary newline, and the deleted range consumes it.
export function visualRange(text, anchor, head, linewise = false) {
  const length = text.length
  const safeAnchor = Math.max(0, Math.min(anchor ?? 0, length))
  const safeHead = Math.max(0, Math.min(head ?? 0, length))
  if (linewise) return lineVisualRange(text, safeAnchor, safeHead)
  return characterVisualRange(text, safeAnchor, safeHead)
}

function characterVisualRange(text, anchor, head) {
  const start = Math.min(anchor, head)
  const end = Math.max(anchor, head)
  const exclusiveEnd = isEndCaret(text, end) ? end : Math.min(text.length, end + 1)
  return {
    range: [start, exclusiveEnd],
    text: text.slice(start, exclusiveEnd),
    linewise: false
  }
}

function lineVisualRange(text, anchor, head) {
  const earlier = lineBoundsAt(text, Math.min(anchor, head))
  const later = lineBoundsAt(text, Math.max(anchor, head))
  const start = earlier.start
  const end = later.end
  const lineText = text.slice(start, end)
  if (end < text.length && text[end] === "\n") {
    return { range: [start, end + 1], text: lineText, linewise: true }
  }
  if (start > 0 && text[start - 1] === "\n") {
    return { range: [start - 1, end], text: lineText, linewise: true }
  }
  return { range: [start, end], text: lineText, linewise: true }
}
