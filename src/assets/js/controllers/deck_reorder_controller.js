import { Controller } from "@hotwired/stimulus"

/**
 * Reorder a deck pane on the client. Re-rendering, or letting Turbo
 * morph, resets every pane's scroll position.
 */
export default class extends Controller {
  static values = { overflow: Boolean }

  move(event) {
    const form = event.currentTarget
    const pane = this.element
    const deck = pane.parentElement
    const direction = form.dataset.deckReorderDirection

    const panes = this.panes(deck)
    const position = panes.indexOf(pane) + (direction === "left" ? -1 : 1)
    const sibling = panes[position]

    // at the ends, the move pages a feed on or off the deck, changing
    // the stream subscriptions. let the form navigate and rebuild them.
    if (!sibling) return

    event.preventDefault()

    if (direction === "left") {
      this.place(deck, pane, sibling)
    } else {
      this.place(deck, sibling, pane)
    }

    this.disableEnds(deck)

    this.write(deck, form, position)
  }

  // Records the new order. Writes are serialized.
  write(deck, form, position) {
    const body = new URLSearchParams(new FormData(form))
    body.set("position", position)
    const pending = deck.pendingWrite || Promise.resolve()
    deck.pendingWrite = pending.then(() =>
      fetch(form.action, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: body
      }).catch(() => {})
    )
  }

  // Moves `first` so that it immediately precedes `second`. Restores
  // the scroll position by hand, because `insertBefore` detaches.
  place(deck, first, second) {
    const scrollTop = first.scrollTop
    deck.insertBefore(first, second)
    first.scrollTop = scrollTop
  }

  panes(deck) {
    return Array.from(deck.querySelectorAll(":scope > .deck-pane"))
  }

  disableEnds(deck) {
    const panes = this.panes(deck)
    panes.forEach((pane, index) => {
      this.disable(pane, "left", index === 0)
      this.disable(pane, "right", index === panes.length - 1 && !this.overflowValue)
    })
  }

  disable(pane, direction, disabled) {
    const button = pane.querySelector(`[data-deck-reorder-direction='${direction}'] button`)
    if (!button) return
    button.disabled = disabled
    button.classList.toggle("disabled", disabled)
  }
}
