// The DOM for a criteria term.

import { classifyTerm, hasBoundarySpace, segmentTerm } from "./criteria_terms"

// Builds the label for a term.
//
export function renderLabel(term) {
  const label = document.createElement("span")
  label.className = `ui label ${classifyTerm(term)}`

  label.title = hasBoundarySpace(term) ? JSON.stringify(term) : term
  label.setAttribute("aria-label", label.title)

  if (hasBoundarySpace(term)) {
    label.classList.add("boundary-space")
  }

  const text = document.createElement("span")
  text.className = "text"

  segmentTerm(term).forEach((run) => {
    if (run.space) {
      const space = document.createElement("span")
      space.className = "space"
      space.textContent = "·".repeat(run.text.length)
      text.appendChild(space)
    } else {
      text.appendChild(document.createTextNode(run.text))
    }
  })

  label.appendChild(text)

  const icon = document.createElement("i")
  icon.className = "delete icon"
  icon.setAttribute("aria-hidden", "true")
  label.appendChild(icon)

  return label
}

// Numbers the labels, and gives the list a single tab stop.
//
export function indexLabels(labels, focusIndex) {
  labels.forEach((label, at) => {
    label.dataset.index = at
    label.tabIndex = at === focusIndex ? 0 : -1
    const icon = label.querySelector(".delete.icon")
    if (icon) {
      icon.dataset.index = at
    }
  })
}
