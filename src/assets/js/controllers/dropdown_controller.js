import { Controller } from "@hotwired/stimulus"

/**
 * Show/hide a dropdown menu.
 */
export default class extends Controller {
  click(event) {
    let menu = this.element.querySelector(".menu")
    if (menu) {
      menu.style.display =
        menu.style.display ?
        null : "block"
    }
  }
}
