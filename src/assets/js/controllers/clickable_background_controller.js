import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { href : String }
  }

  // bind the necessary events directly--don't treat them as
  // traditional stimulus actions--because all are required, and a
  // client accidently omitting one, or configuring it incorrectly,
  // will break the controller's expected behavior.

  eventsToBind = [
    { name : "mousedown", handler : this.mousedown.bind(this) },
    { name : "mousemove", handler : this.mousemove.bind(this) },
    { name : "click", handler : this.click.bind(this) }
  ]

  connect() {
    for (event of this.eventsToBind) {
      this.element.addEventListener(event.name, event.handler)
    }
  }

  disconnect() {
    for (event of this.eventsToBind) {
      this.element.removeEventListener(event.name, event.handler)
    }
  }

  mousedown(event) {
    this.moved = false
  }

  mousemove(event) {
    this.moved = true
  }

  click(event) {
    if (this.moved)
      return
    if (this.hrefValue && !event.target.closest("a, button, input, img")) {
      if (this.hrefValue[0] != "/" && new URL(this.hrefValue).host != window.location.host) {
        window.open(this.hrefValue, "_blank")
      } else {
        Turbo.visit(this.hrefValue)
      }
    }
  }
}
