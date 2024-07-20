import { Controller } from "@hotwired/stimulus"
import Trix from "trix"

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

// Additional editor properties/state:
//
// - suggestion: the current suggestion
// - change_lock: short-circuits change events (and prevents multiple
//   calls to the backend) when typing quickly
// - backspaced: prevents a new suggestion from being presented after
//   backspacing/canceling the previous suggestion
//
export default class extends Controller {
  change(event) {
    let editor =  event.target.editor
    let document = editor.getDocument().toString()
    let position = editor.getPosition()
    if (editor.change_lock)
      return
    if (editor.backspaced) {
      editor.backspaced = false
      return
    }
    for (var i = 1; i < 64; i++) {
      let ch1 = document[position - i]
      let ch2 = document[position - i - 1]
      if ((ch1 == "#" || ch1 == "@") && (ch2 == " " || ch2 == "\n" || !ch2)) {
        break
      }
      if (ch1 == " " || ch1 == "\n" || !ch1) {
        i--
        break
      }
    }
    for (var j = 0; j < 64; j++) {
      let ch = document[position + j]
      if (ch == " " || ch == "\n" || !ch) {
        break
      }
    }
    let prefix = document.substring(position - i, position)
    let suffix = document.substring(position, position + j)
    if (!suffix && prefix.length > 2 && (prefix[0] == "#" || prefix[0] == "@")) {
      editor.change_lock = true
      if (!editor.suggestion || !editor.suggestion.startsWith(prefix)) {
        let url
        switch (prefix[0]) {
        case "#":
          url = `/tags?hashtag=${prefix.slice(1)}`
          break
        case "@":
          url = `/tags?mention=${prefix.slice(1)}`
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
        }
      }
      if (editor.suggestion && editor.suggestion.toLowerCase().startsWith(prefix.toLowerCase())) {
        let suggestion = editor.suggestion.substring(prefix.length)
        editor.insertString(suggestion)
        editor.setSelectedRange([position, position + suggestion.length])
      }
      editor.change_lock = false
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
}
