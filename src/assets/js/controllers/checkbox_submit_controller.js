import { Controller } from "@hotwired/stimulus"

/**
 * Submit form when checkbox toggles.
 *
 * Wiring the change event directly to the form submit method does not
 * work with Turbo--Turbo doesn't intercept it. Instead, create a
 * hidden submit button and click that.
 */
export default class extends Controller {
  connect() {
    let input = document.createElement("input")
    input.type = "submit"
    input.style.display = "none"
    this.element.appendChild(input)
    this.input = input
  }

  change(event) {
    this.input.click()
  }
}
