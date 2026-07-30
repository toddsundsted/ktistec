// Where a dragged term would drop.

// Where the other terms sit with the dragged term taken out of the
// flow.
//
export function measureSlots(labels, dragged) {
  const display = dragged ? dragged.style.display : null
  if (dragged) {
    dragged.style.display = "none"
  }
  const x = window.scrollX
  const y = window.scrollY
  const slots = labels
    .filter((label) => label !== dragged)
    .map((label) => {
      const rect = label.getBoundingClientRect()
      return {
        left: rect.left + x,
        right: rect.right + x,
        top: rect.top + y,
        bottom: rect.bottom + y,
      }
    })
  if (dragged) {
    dragged.style.display = display
  }
  return slots
}

// The slot the term would drop.
//
export function insertionIndex(slots, x, y) {
  let index = 0
  slots.forEach((rect) => {
    const past = y > rect.bottom || (y >= rect.top && x > (rect.left + rect.right) / 2)
    if (past) {
      index += 1
    }
  })
  return index
}
