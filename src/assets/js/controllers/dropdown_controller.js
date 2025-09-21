import { Controller } from "@hotwired/stimulus"

/**
 * Show/hide a dropdown menu.
 */
export default class extends Controller {
  click(event) {
    let menu = this.element.querySelector(".menu")
    if (menu && (event.target === this.element || !menu.contains(event.target))) {
      menu.style.display =
        menu.style.display ?
        null : "block"
    }
  }
}
