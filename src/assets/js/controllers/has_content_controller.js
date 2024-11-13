import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "input", "button" ]
  }

  check(event) {
    let hasContent = !!this.inputTarget.textContent
    this.buttonTargets.forEach(function(target) {
      let enabled = !target.classList.contains("disabled")
      if (hasContent != enabled) {
        hasContent ?
          target.classList.remove("disabled") :
          target.classList.add("disabled")
      }
    })
  }
}
