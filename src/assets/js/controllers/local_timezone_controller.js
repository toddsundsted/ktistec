import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    let placeholder = `IANA time zone database identifier. For example: ${timezone}`
    let placeholderOnly = this.element.dataset["placeholder-only"]
    this.element.setAttribute("placeholder", placeholder)
    if (!placeholderOnly) {
      if (!this.element.value && !this.element.closest(".field.error")) {
        this.element.value = timezone
      }
    }
  }
}
