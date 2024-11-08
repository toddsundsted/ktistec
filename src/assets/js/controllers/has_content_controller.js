import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "input", "button" ]
  }

  check() {
    if (this.hasContent != !!this.inputTarget.textContent) {
      let hasContent = (this.hasContent = !!this.inputTarget.textContent)
      Array.prototype.forEach.call(this.buttonTargets, function(target) {
        hasContent ?
          target.classList.remove("disabled") :
          target.classList.add("disabled")
      })
    }
  }
}
