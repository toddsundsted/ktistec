import { Controller } from "@hotwired/stimulus"

/**
 * Copy text to clipboard when clicked.
 */
export default class extends Controller {
  static values = { text: String }

  click(event) {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const originalIcon = this.element
      const originalClasses = originalIcon.className

      originalIcon.className = originalIcon.className.replace('copy', 'check')
      originalIcon.style.color = '#21ba45'

      setTimeout(() => {
        originalIcon.style.opacity = '0'
        originalIcon.addEventListener('transitionend', () => {
          originalIcon.className = originalClasses
          originalIcon.style.opacity = '1'
          originalIcon.style.color = ''
        }, { once: true })
      }, 1000)
    }).catch(err => {
      console.error('Failed to copy text: ', err)
    })
  }
}
