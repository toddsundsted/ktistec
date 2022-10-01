import { Controller } from "@hotwired/stimulus"

/**
 * Refresh actors with unloadable icon images.
 */
export default class extends Controller {
  connect() {
    this.element.querySelectorAll(".ui.feed .event img[data-actor-id]").forEach(function(element) {
      element.addEventListener("error", () => {
        let replacement = document.createElement("i")
        replacement.className = "user icon"
        element.replaceWith(replacement)
        let xhr = new XMLHttpRequest()
        xhr.open("POST", `/remote/actors/${element.dataset.actorId}/refresh`)
        xhr.setRequestHeader("X-CSRF-Token", Ktistec.csrf)
        xhr.send()
      })
    })
  }
}
