import { Controller } from "@hotwired/stimulus"
import Trix from "trix"

Trix.config.attachments.preview.caption = {
  name: false,
  size: false
}

function extend_handler(controller) {
  let previous_keydown = controller.events.keydown
  controller.events.keydown = function(event) {
    let editor = this.delegate.editor
    if (editor.suggestion) {
      switch (event.keyCode) {
      case 8: /* backspace */
        editor.backspaced = true
        break
      case 27: /* escape */
        editor.insertString("")
        editor.selectionManager.delegate.requestedRender = true
        editor.backspaced = true
        event.preventDefault()
        break
      case 9: /* tab */
        let [begin, end] = editor.getSelectedRange()
        editor.setSelectedRange([end, end])
        editor.suggestion = undefined
        event.preventDefault()
        break
      }
    }
    previous_keydown.call(this, event)
  }
}

extend_handler(Trix.controllers.Level0InputController)
extend_handler(Trix.controllers.Level2InputController)

// Autocompletes hashtags and mentions as the user types.
//
// Additional editor properties/state:
//
// Autocomplete:
// - suggestion: the current suggestion
// - changeLock: short-circuits change events during autocomplete
// - backspaced: prevents new suggestion after backspacing/canceling
//
export default class extends Controller {
  static targets = ["trixEditor"]

  connect() {
    this.createAltTextModal()

    this.boundAdd = this.add.bind(this)
    this.boundRemove = this.remove.bind(this)
    this.boundChange = this.change.bind(this)
    this.boundBeforeToolbar = this.beforeToolbar.bind(this)

    this.element.addEventListener('trix-attachment-add', this.boundAdd)
    this.element.addEventListener('trix-attachment-remove', this.boundRemove)
    this.element.addEventListener('trix-change', this.boundChange)
    this.element.addEventListener('trix-attachment-before-toolbar', this.boundBeforeToolbar)
  }

  disconnect() {
    if (this.altTextModal) {
      this.altTextModal.remove()
      this.altTextModal = null
    }

    if (this.boundAdd) {
      this.element.removeEventListener('trix-attachment-add', this.boundAdd)
      this.element.removeEventListener('trix-attachment-remove', this.boundRemove)
      this.element.removeEventListener('trix-change', this.boundChange)
      this.element.removeEventListener('trix-attachment-before-toolbar', this.boundBeforeToolbar)
    }
  }

  change(event) {
    let editor =  event.target.editor
    let document = editor.getDocument().toString()
    let position = editor.getPosition()
    if (editor.changeLock)
      return
    if (editor.backspaced) {
      editor.backspaced = false
      return
    }
    // Scan backward to find the start of the current word, looking
    // for a `#` or `@` prefix that indicates a hashtag or mention.
    // Word boundaries include:
    // - any whitespace character (space, tab, newline, etc.)
    // - \uFFFC (Object Replacement Character - used by Trix for attachments)
    // - `undefined` (start/end of document)
    for (var i = 1; i < 64; i++) {
      let ch1 = document[position - i]
      let ch2 = document[position - i - 1]
      if ((ch1 == "#" || ch1 == "@") && (/\s/.test(ch2) || ch2 == "\uFFFC" || !ch2)) {
        break
      }
      if (/\s/.test(ch1) || ch1 == "\uFFFC" || !ch1) {
        i--
        break
      }
    }
    // Scan forward to find the end of the current word.
    for (var j = 0; j < 64; j++) {
      let ch = document[position + j]
      if (/\s/.test(ch) || ch == "\uFFFC" || !ch) {
        break
      }
    }
    let prefix = document.substring(position - i, position)
    let suffix = document.substring(position, position + j)
    if (!suffix && prefix.length > 2 && (prefix[0] == "#" || prefix[0] == "@")) {
      editor.changeLock = true
      if (!editor.suggestion || !editor.suggestion.startsWith(prefix)) {
        let url
        switch (prefix[0]) {
        case "#":
          url = `/tags?hashtag=${encodeURIComponent(prefix.slice(1))}`
          break
        case "@":
          url = `/tags?mention=${encodeURIComponent(prefix.slice(1))}`
          break
        }
        if (url) {
          fetch(url)
            .then(function(response) {
              return response.text()
            })
            .then(function(suggestion) {
              editor.suggestion = `${prefix[0]}${suggestion}`
            })
            .catch(async (error) => {
              console.error('Autocomplete fetch failed:', error)
              editor.suggestion = null
            })
        }
      }
      if (editor.suggestion && editor.suggestion.toLowerCase().startsWith(prefix.toLowerCase())) {
        let suggestion = editor.suggestion.substring(prefix.length)
        editor.insertString(suggestion)
        editor.setSelectedRange([position, position + suggestion.length])
      }
      editor.changeLock = false
    }
  }

  add(event) {
    let attachment = event.attachment
    if (attachment.file) {
      let fd = new FormData()
      fd.append("Content-Type", attachment.file.type)
      fd.append("file", attachment.file)
      let xhr = new XMLHttpRequest()
      xhr.open("POST", "/uploads")
      xhr.setRequestHeader("X-CSRF-Token", Ktistec.csrf)
      xhr.upload.addEventListener("progress", function(event) {
        if (event.lengthComputable) {
          var progress = event.loaded / event.total * 100
          attachment.setUploadProgress(progress)
        }
      }, false)
      xhr.addEventListener("progress", function(event) {
        if (event.lengthComputable) {
          var progress = event.loaded / event.total * 100
          attachment.setUploadProgress(progress)
        }
      }, false)
      xhr.addEventListener("load", function(event) {
        if (xhr.status == 201) {
          attachment.setAttributes({
            url: xhr.getResponseHeader("Location"),
            href: xhr.getResponseHeader("Location")
          })
        }
      })
      xhr.send(fd)
    }
  }

  remove(event) {
    let attachment = event.attachment.attachment
    if (attachment.previewURL) {
      let xhr = new XMLHttpRequest()
      xhr.open("DELETE", attachment.previewURL)
      xhr.setRequestHeader("X-CSRF-Token", Ktistec.csrf)
      xhr.send()
    }
  }

  beforeToolbar(event) {
    const attachment = event.attachment
    const toolbar = event.toolbar

    if (!attachment || !toolbar) return

    if (!attachment.isPreviewable || !attachment.isPreviewable()) return

    if (toolbar.querySelector('[data-alt-text-button]')) return

    let buttonRow = toolbar.querySelector('.trix-button-row')
    if (!buttonRow) {
      buttonRow = document.createElement('div')
      buttonRow.className = 'trix-button-row'
      toolbar.appendChild(buttonRow)
    }

    let buttonGroup = buttonRow.querySelector('.trix-button-group')
    if (!buttonGroup) {
      buttonGroup = document.createElement('div')
      buttonGroup.className = 'trix-button-group'
      buttonRow.appendChild(buttonGroup)
    }

    const altTextButton = document.createElement('button')
    altTextButton.type = 'button'
    altTextButton.className = 'trix-button trix-button--alt-text'
    altTextButton.setAttribute('title', 'Edit alt text')
    altTextButton.textContent = 'Alt Text'

    altTextButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.showAltTextModal(attachment)
    })

    const removeButton = document.createElement('button')
    removeButton.type = 'button'
    removeButton.className = 'trix-button trix-button--alt-remove'
    removeButton.setAttribute('data-trix-action', 'remove')
    removeButton.setAttribute('title', 'Remove')
    removeButton.textContent = 'Remove'

    const oldButton = buttonGroup.querySelector('[data-trix-action="remove"]')
    if (oldButton) {
      buttonGroup.insertBefore(altTextButton, oldButton)
      buttonGroup.insertBefore(removeButton, oldButton)
      buttonGroup.removeChild(oldButton)
    } else {
      buttonGroup.appendChild(altTextButton)
      buttonGroup.appendChild(removeButton)
    }
  }

  createAltTextModal() {
    if (this.altTextModal) return

    const modal = document.createElement('div')
    modal.className = 'trix-alt-text-modal'
    modal.setAttribute('aria-hidden', 'true')
    modal.setAttribute('aria-modal', 'true')
    modal.setAttribute('aria-label', 'Edit image alt text')
    modal.setAttribute('role', 'dialog')

    const overlay = document.createElement('div')
    overlay.className = 'modal-overlay'
    overlay.addEventListener('click', () => this.hideAltTextModal())

    const content = document.createElement('div')
    content.className = 'modal-content'

    const body = document.createElement('div')
    body.className = 'modal-body'

    const textarea = document.createElement('textarea')
    textarea.id = 'trix-alt-textarea'
    textarea.setAttribute('placeholder', 'Describe the image')

    body.appendChild(textarea)

    const footer = document.createElement('div')
    footer.className = 'modal-footer'

    const saveButton = document.createElement('button')
    saveButton.className = 'ui tiny primary button'
    saveButton.type = 'button'
    saveButton.textContent = 'Save'
    saveButton.addEventListener('click', () => this.saveAltText())

    const cancelButton = document.createElement('button')
    cancelButton.className = 'ui tiny button'
    cancelButton.type = 'button'
    cancelButton.textContent = 'Cancel'
    cancelButton.addEventListener('click', () => this.hideAltTextModal())

    footer.appendChild(saveButton)
    footer.appendChild(cancelButton)

    content.appendChild(body)
    content.appendChild(footer)

    modal.appendChild(overlay)
    modal.appendChild(content)

    modal.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        this.hideAltTextModal()
      } else if (e.key === 'Enter' && !e.shiftKey && e.target === textarea) {
        e.preventDefault()
        this.saveAltText()
      } else if (e.key === 'Tab') {
        // focus trap
        const focusable = modal.querySelectorAll('button, textarea, [tabindex]:not([tabindex="-1"])')
        const first = focusable[0]
        const last = focusable[focusable.length - 1]
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault()
          last.focus()
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault()
          first.focus()
        }
      }
    })

    document.body.appendChild(modal)

    this.altTextModal = modal
  }

  showAltTextModal(attachment) {
    this.currentAttachment = attachment

    const textarea = this.altTextModal.querySelector('textarea')
    textarea.value = attachment.getAttribute('alt') || ''

    this.altTextModal.setAttribute('aria-hidden', 'false')

    requestAnimationFrame(() => {
      textarea.focus()
      textarea.select()
    })
  }

  hideAltTextModal() {
    if (!this.altTextModal) return

    this.altTextModal.setAttribute('aria-hidden', 'true')

    this.currentAttachment = null
  }

  saveAltText() {
    if (!this.currentAttachment) return

    const textarea = this.altTextModal.querySelector('textarea')
    const altText = textarea.value.trim()

    this.currentAttachment.setAttributes({ alt: altText })

    this.hideAltTextModal()
  }
}
