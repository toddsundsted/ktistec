import { Controller } from "@hotwired/stimulus"

// Manages button states and autosave functionality for editors.
//
// Features:
// 1. Enables/disables buttons based on whether content exists
// 2. Autosaves draft content periodically when typing
// 3. Warns user about unsaved changes when closing tab/window
// 4. Restores focus and cursor position after autosave
//
// Targets:
// - input: the textarea/input containing the content
// - button: all buttons that should be enabled/disabled based on content
// - saveDraftButton: the specific button to click for autosave (optional)
//
// Focus and cursor position restoration:
//
// Autosave triggers a form submit; the server responds with a Turbo Stream
// that replaces the form (action="replace" method="morph"). The morph can
// replace the editor DOM, so the previously focused element may be
// disconnected and focus is lost. To fix that:
//
// 1. Before clicking save, capture which editor (Trix or Markdown) has focus
//    and its selection/cursor (Trix range or textarea selectionStart/End --
//    a collapsed selection is the caret position).
//
// 2. Register a one-time turbo:before-stream-render listener that, after the
//    stream render completes, finds the current editor and restores focus
//    and cursor/selection position.
//
// 3. The current editor is either the captured element if it is still in the
//    DOM (e.g. later autosaves when the form id is stable), or the editor
//    inside the element with id="editor-field" in the new HTML.
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

    const focusState = this._captureFocusState()

    this.lastSavedContent = this.inputTarget.value
    this.isSaving = true

    if (focusState) {
      this._setupFocusRestore(focusState)
    }

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

  _editorIn(container) {
    const trix = container?.querySelector('trix-editor')
    if (trix) return { type: 'trix', element: trix }
    const markdown = container?.querySelector('textarea.markdown-editor')
    if (markdown) return { type: 'markdown', element: markdown }
    return null
  }

  _captureFocusState() {
    const found = this._editorIn(this.element)
    if (!found || (document.activeElement !== found.element && !found.element.contains(document.activeElement))) {
      return null
    }
    const state = { type: found.type, element: found.element }
    if (found.type === 'trix') {
      state.range = found.element.editor?.getSelectedRange()
    } else {
      state.selectionStart = found.element.selectionStart
      state.selectionEnd = found.element.selectionEnd
    }
    return state
  }

  _setupFocusRestore(focusState) {
    document.addEventListener('turbo:before-stream-render', (event) => {
      const originalRender = event.detail.render
      event.detail.render = async (streamElement) => {
        await originalRender(streamElement)
        this._restoreFocusState(focusState)
      }
    }, { once: true })
  }

  _restoreFocusState(focusState) {
    // focus the editor
    const target = focusState.element.isConnected
      ? focusState.element
      : this._editorIn(document.getElementById('editor-field'))?.element
    if (!target?.isConnected) return
    target.focus()

    // restore cursor/selection
    if (focusState.type === 'trix' && focusState.range != null && target.editor) {
      target.editor.setSelectedRange(focusState.range)
    } else if (focusState.type === 'markdown' && focusState.selectionStart != null) {
      target.selectionStart = focusState.selectionStart
      target.selectionEnd = focusState.selectionEnd
    }
  }
}
