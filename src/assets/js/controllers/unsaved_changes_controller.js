import { Controller } from "@hotwired/stimulus"

// Warns before leaving a form with unsaved changes.
//
// Two exits are covered: `beforeunload` for closing the tab or
// reloading, and `turbo:before-visit` for in-app links.
//
// A third exit is not covered: browser Back/Forward. Turbo excludes
// restoration visits from `turbo:before-visit`, and `beforeunload`
// doesn't fire for an in-app navigation, so leaving a dirty form by
// Back/Forward navigation discards it silently.
//
export default class extends Controller {
  static values = { message: { type: String, default: "You have unsaved changes. Discard them?" } }

  connect() {
    this.baseline = this.serialize()

    this.beforeVisitHandler = (event) => this._beforeVisit(event)
    this.beforeUnloadHandler = (event) => this._beforeUnload(event)
    this.submitHandler = () => this._submit()

    document.addEventListener("turbo:before-visit", this.beforeVisitHandler)
    window.addEventListener("beforeunload", this.beforeUnloadHandler)
    this.element.addEventListener("submit", this.submitHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler)
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
    this.element.removeEventListener("submit", this.submitHandler)
  }

  // The form's state as a comparable string.
  //
  // Escaped, so that a value containing separators can't make two
  // different states compare equal.
  //
  serialize() {
    const pairs = []
    for (const [name, value] of new FormData(this.element)) {
      pairs.push(`${encodeURIComponent(name)}=${encodeURIComponent(value)}`)
    }
    return pairs.join("&")
  }

  // Whether the form differs from the last saved state.
  //
  changed() {
    return this.serialize() !== this.baseline
  }

  _submit() {
    this.baseline = this.serialize()
  }

  _beforeVisit(event) {
    if (this.changed() && !window.confirm(this.messageValue)) {
      event.preventDefault()
    }
  }

  _beforeUnload(event) {
    if (this.changed()) {
      event.preventDefault()
      event.returnValue = ""
    }
  }
}
