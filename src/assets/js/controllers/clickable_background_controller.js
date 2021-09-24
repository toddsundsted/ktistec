import { Controller } from "stimulus"

export default class extends Controller {
  static get values() {
    return { href : String }
  }

  click(event) {
    if (this.hrefValue && !event.target.closest("a, button, input, img")) {
      if (this.hrefValue[0] != "/" && new URL(this.hrefValue).host != window.location.host) {
        window.open(this.hrefValue, "_blank")
      } else {
        Turbo.visit(this.hrefValue)
      }
    }
  }
}
