import { Controller } from "@hotwired/stimulus"

/**
 * Refresh actors with unloadable icon images.
 */
export default class extends Controller {
  connect() {
    // the `error` event does not bubble, so handle it during the
    // capture phase (`addEventListener(..., true)`).
    this.element.addEventListener("error", (event) => {
      let element = event.target
      if (element.matches("img[data-actor-id]")) {
        let replacement = document.createElement("i")
        replacement.className = "user icon"
        element.replaceWith(replacement)
        let xhr = new XMLHttpRequest()
        xhr.open("POST", `/remote/actors/${element.dataset.actorId}/refresh`)
        xhr.setRequestHeader("X-CSRF-Token", Ktistec.csrf)
        xhr.send()
      }
    }, true)
  }
}
