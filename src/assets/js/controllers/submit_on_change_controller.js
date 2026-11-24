import { Controller } from "@hotwired/stimulus"

/**
 * Submit form when an input changes.
 *
 * Submits with `requestSubmit()`, which dispatches a `submit` event
 * that Turbo intercepts (`submit()` does not).
 */
export default class extends Controller {
  change(event) {
    this.element.requestSubmit()
  }
}
