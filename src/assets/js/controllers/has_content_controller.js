import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "input", "button" ]
  }

  check() {
    if (this.hasContent != !!this.inputTarget.textContent) {
      let hasContent = (this.hasContent = !!this.inputTarget.textContent)
      let turboStreamSources = document.querySelectorAll('turbo-stream-source')
      turboStreamSources.forEach((turboStreamSource) => {
        hasContent ?
          Turbo.session.disconnectStreamSource(turboStreamSource.streamSource) :
          Turbo.session.connectStreamSource(turboStreamSource.streamSource)
      })
      Array.prototype.forEach.call(this.buttonTargets, function(target) {
        hasContent ?
          target.classList.remove("disabled") :
          target.classList.add("disabled")
      })
    }
  }
}
