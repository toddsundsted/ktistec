import { Controller } from "@hotwired/stimulus"

/**
 * Submit form when an input changes.
 *
 * Wiring the change event directly to the form submit method does not
 * work with Turbo--Turbo doesn't intercept it. Instead, create a
 * hidden submit button and click that.
 *
 * Hides its fallback targets once it's connected.
 */
export default class extends Controller {
  static targets = ["fallback"]

  connect() {
    let input = document.createElement("input")
    input.type = "submit"
    input.style.display = "none"
    this.element.appendChild(input)
    this.input = input
    this.fallbackTargets.forEach((fallback) => fallback.style.display = "none")
  }

  disconnect() {
    this.input.remove()
  }

  change(event) {
    this.input.click()
  }
}
