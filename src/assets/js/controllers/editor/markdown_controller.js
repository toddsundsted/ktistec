import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // defer height adjustment until content is fully rendered
    requestAnimationFrame(() => {
      this.adjustHeight()
    })
  }

  input(event) {
    this.adjustHeight()
  }

  adjustHeight() {
    const element = this.element
    // reset height to get accurate scrollHeight
    element.style.height = 'auto'
    // set height to scrollHeight
    element.style.height = element.scrollHeight + 'px'
  }
}
