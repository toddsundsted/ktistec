import { Controller } from "stimulus"

export default class extends Controller {
  static get values() {
    return { href : String }
  }

  click(event) {
    if (!["A", "BUTTON", "IMG", "INPUT"].includes(event.target.tagName) && this.hrefValue) {
      Turbolinks.visit(this.hrefValue)
    }
  }
}
