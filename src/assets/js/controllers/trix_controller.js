import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    let editor = this.element.editor
    let previous_keydown = editor.composition.delegate.inputController.events.keydown
    editor.composition.delegate.inputController.events.keydown = function(keydown) {
      if (keydown.keyCode == 8 /* backspace */ && editor.suggestion) {
        editor.backspacing = true
      }
      else if (keydown.keyCode == 27 /* escape */ && editor.suggestion) {
        editor.insertString("")
        editor.selectionManager.delegate.requestedRender = true
        editor.backspacing = true
        keydown.preventDefault()
      }
      else if (keydown.keyCode == 9 /* tab */ && editor.suggestion) {
        let [begin, end] = editor.getSelectedRange()
        editor.setSelectedRange([end, end])
        editor.suggestion = undefined
        keydown.preventDefault()
      }
      previous_keydown.call(this, keydown)
    }
  }

  change(event) {
    let editor =  event.target.editor
    let document = editor.getDocument().toString()
    let position = editor.getPosition()
    if (editor.edit_lock)
      return
    if (editor.backspacing) {
      editor.backspacing = false
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
      editor.edit_lock = true
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
      editor.edit_lock = false
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
