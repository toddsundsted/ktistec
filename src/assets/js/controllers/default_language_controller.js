import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const language = navigator.language
    if (!this.element.value && !this.element.closest(".field.error")) {
      this.element.value = language
    }
  }
}
