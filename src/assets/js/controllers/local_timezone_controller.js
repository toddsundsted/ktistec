import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!this.element.value && !this.element.closest(".field.error")) {
      this.element.value = timezone
    }
  }
}
