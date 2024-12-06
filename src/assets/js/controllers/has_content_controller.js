import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "input", "button" ]
  }

  connect() {
    this._check(null)
  }

  check(event) {
    this._check(event)
  }

  _check(event) {
    let hasContent = !!this.inputTarget.value
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
