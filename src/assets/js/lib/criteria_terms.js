// The criteria terms of a feed, as text and as a list.

// Splits text into terms.
//
export function splitTerms(text) {
  return text.replace(/\r\n/g, "\n").split("\n").filter((line) => line.trim() !== "")
}

// Joins terms into text.
//
export function serialize(terms) {
  return terms.join("\n")
}

// Infers a term's type.
//
export function classifyTerm(term) {
  if (term.startsWith("#")) {
    return "hashtag"
  }
  if (term.startsWith("@") || /^https?:\/\//i.test(term)) {
    return "mention"
  }
  return "keyword"
}

// Splits a term into alternating runs of whitespace and everything
// else.
//
export function segmentTerm(term) {
  const runs = []
  for (const text of term.match(/\s+|\S+/g) || []) {
    runs.push({ space: /\s/.test(text[0]), text: text })
  }
  return runs
}

// Whether a term's whitespace is leading or trailing.
//
export function hasBoundarySpace(term) {
  return /^\s|\s$/.test(term)
}

// Moves the term at `from` to `to`.
//
export function moveTerm(terms, from, to) {
  if (from < 0 || from >= terms.length) {
    return terms
  }
  const moved = terms.slice()
  const [term] = moved.splice(from, 1)
  moved.splice(Math.max(0, Math.min(to, moved.length)), 0, term)
  return moved
}
