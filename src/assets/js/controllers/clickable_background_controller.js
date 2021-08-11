import { Controller } from "stimulus"

export default class extends Controller {
  static get values() {
    return { href : String }
  }

  click(event) {
    if (this.hrefValue && !event.target.closest("a, button, input, img")) {
      Turbo.visit(this.hrefValue)
    }
  }
}
