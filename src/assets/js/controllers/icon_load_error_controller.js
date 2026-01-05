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
        let replacement = document.createElement("img")
        replacement.className = "ui avatar image"
        replacement.setAttribute("src", "/images/avatars/fallback.png")
        replacement.dataset.actorId = element.dataset.actorId
        element.replaceWith(replacement)
        if (Ktistec.auth) {
          let xhr = new XMLHttpRequest()
          let data = "sync-featured-collection=false"
          xhr.open("POST", `/remote/actors/${element.dataset.actorId}/refresh`, true)
          xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded")
          xhr.setRequestHeader("X-CSRF-Token", Ktistec.csrf)
          xhr.send(data)
        }
      }
    }, true)
  }
}
