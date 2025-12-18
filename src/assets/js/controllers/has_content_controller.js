import { Controller } from "@hotwired/stimulus"

// Manages button states and autosave functionality for editors.
//
// Features:
// 1. Enables/disables buttons based on whether content exists
// 2. Autosaves draft content periodically when typing
// 3. Warns user about unsaved changes when closing tab/window
//
// Targets:
// - input: the textarea/input containing the content
// - button: all buttons that should be enabled/disabled based on content
// - saveDraftButton: the specific button to click for autosave (optional)
//
export default class extends Controller {
  static get targets() {
    return ["input", "button", "saveDraftButton"]
  }

  connect() {
    this._check(null)

    this.autosaveTimeout = null
    this.lastSavedContent = this.inputTarget.value
    this.isSaving = false
    this.beforeUnloadHandler = (event) => {
      if (this.hasContentChanged()) {
        event.preventDefault()
        event.returnValue = '' // Chrome requires this
      }
    }
    window.addEventListener('beforeunload', this.beforeUnloadHandler)
  }

  disconnect() {
    if (this.autosaveTimeout) {
      clearTimeout(this.autosaveTimeout)
    }
    window.removeEventListener('beforeunload', this.beforeUnloadHandler)
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

  scheduleAutosave(event) {
    if (this.autosaveTimeout) {
      clearTimeout(this.autosaveTimeout)
    }
    this.autosaveTimeout = setTimeout(() => {
      this.performAutosave()
    }, 2000)
  }

  performAutosave() {
    if (!this.hasContentChanged() || this.isSaving) {
      return
    }
    if (!this.hasSaveDraftButtonTarget) {
      return
    }

    const saveDraftButton = this.saveDraftButtonTarget

    if (saveDraftButton.classList.contains("disabled")) {
      return
    }

    this.lastSavedContent = this.inputTarget.value
    this.isSaving = true

    saveDraftButton.click()
    saveDraftButton.classList.add("disabled")

    const spinnerIcon = document.createElement('i')
    spinnerIcon.className = 'sync loading icon'
    saveDraftButton.prepend(spinnerIcon)

    // reset button state after a short delay
    setTimeout(() => {
      this.isSaving = false

      saveDraftButton.classList.remove("disabled")

      const spinnerIcon = saveDraftButton.querySelector('i.sync.loading.icon')
      if (spinnerIcon) {
        spinnerIcon.remove()
      }
    }, 1000)
  }

  hasContentChanged() {
    return this.inputTarget.value !== this.lastSavedContent
  }

  blur(event) {
    this.performAutosave()
  }
}
