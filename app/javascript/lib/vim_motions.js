// Pure string/offset calculations for Vim motions on plain-text buffers.
// Note: Trix's editor.getDocument().toString() appends a trailing "\n" for the
// final block break; callers should pass the editable body (without Trix's
// synthetic trailing newline) to these functions.

export function lineBoundsAt(text, offset) {
  if (text.length === 0) return { start: 0, end: 0 }
  const clamped = Math.max(0, Math.min(offset, text.length))
  const searchFrom = clamped > 0 && clamped === text.length && text[clamped - 1] !== "\n"
    ? clamped - 1
    : clamped
  const prevNewline = searchFrom === 0 ? -1 : text.lastIndexOf("\n", searchFrom - 1)
  const start = prevNewline === -1 ? 0 : prevNewline + 1
  const nextNewline = text.indexOf("\n", start)
  const end = nextNewline === -1 ? text.length : nextNewline
  return { start, end }
}

export function clampToLine(text, offset) {
  const { start, end } = lineBoundsAt(text, offset)
  const maxPos = end > start ? end - 1 : start
  return Math.max(start, Math.min(offset, maxPos))
}

export function moveHorizontal(text, offset, delta) {
  const { start, end } = lineBoundsAt(text, offset)
  const maxPos = end > start ? end - 1 : start
  return Math.max(start, Math.min(offset + delta, maxPos))
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
    const targetCol = prevLen > 0 ? Math.min(col, prevLen - 1) : 0
    return { offset: prevStart + targetCol, col }
  } else {
    if (end >= text.length) return { offset, col }
    const nextStart = end + 1
    const nextNewline = text.indexOf("\n", nextStart)
    const nextEnd = nextNewline === -1 ? text.length : nextNewline
    const nextLen = Math.max(0, nextEnd - nextStart)
    const targetCol = nextLen > 0 ? Math.min(col, nextLen - 1) : 0
    return { offset: nextStart + targetCol, col }
  }
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
