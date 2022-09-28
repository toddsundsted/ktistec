import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    this.element.setAttribute("placeholder", timezone)
    if (!this.element.value) {
      this.element.value = timezone
    }
  }
}
