import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const language = navigator.language
    let placeholder = `IETF BCP 47 language tag. For example: ${language}`
    let placeholderOnly = this.element.dataset["placeholder-only"]
    this.element.setAttribute("placeholder", placeholder)
    if (!placeholderOnly) {
      if (!this.element.value && !this.element.closest(".field.error")) {
        this.element.value = language
      }
    }
  }
}
