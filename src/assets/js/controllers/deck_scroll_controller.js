import { Controller } from "@hotwired/stimulus"

/**
 * Restores the deck's scroll positions when navigating back to it.
 *
 * Turbo restores only the window's scroll position, but the deck and
 * its panes scroll themselves, and the clone Turbo caches drops their
 * offsets. Data attributes survive the clone.
 */
export default class extends Controller {
  connect() {
    this.beforeCacheHandler = () => this.save()
    document.addEventListener("turbo:before-cache", this.beforeCacheHandler)
    this.restore()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCacheHandler)
  }

  save() {
    this.element.dataset.deckScrollLeft = this.element.scrollLeft
    for (const pane of this.panes()) {
      pane.dataset.deckScrollTop = pane.scrollTop
    }
  }

  // on a normal visit, Turbo shows the cached page as a preview, then
  // replaces it with a fresh page at the top; restoring the preview
  // would scroll the deck only to have it jump back

  restore() {
    const preview = document.documentElement.hasAttribute("data-turbo-preview")
    const left = this.element.dataset.deckScrollLeft
    if (left !== undefined) {
      if (!preview) this.element.scrollLeft = Number(left)
      delete this.element.dataset.deckScrollLeft
    }
    for (const pane of this.panes()) {
      const top = pane.dataset.deckScrollTop
      if (top !== undefined) {
        if (!preview) pane.scrollTop = Number(top)
        delete pane.dataset.deckScrollTop
      }
    }
  }

  panes() {
    return Array.from(this.element.querySelectorAll(":scope > .deck-pane"))
  }
}
