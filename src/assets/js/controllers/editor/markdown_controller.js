import { Controller } from "@hotwired/stimulus"

// Provides three features:
// 1. autoresizing textarea as content changes
// 2. autocompleting hashtags and mentions as the user types
//
// Additional state:
//
// Autocomplete:
// - suggestion: the current suggestion
// - changeLock: prevents recursive input events during autocomplete
// - backspaced: prevents new suggestion after backspacing/canceling
//
export default class extends Controller {
  connect() {
    this.suggestion = null
    this.changeLock = false
    this.backspaced = false

    this.element.addEventListener('keydown', this.handleKeydown.bind(this))

    // defer height adjustment until content is fully rendered
    requestAnimationFrame(() => {
      this.adjustHeight()
    })
  }

  disconnect() {
    this.element.removeEventListener('keydown', this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    if (this.suggestion) {
      switch (event.keyCode) {
        case 8: /* backspace */
          this.backspaced = true
          break
        case 27: /* escape */
          this.backspaced = true
          this.removeSuggestion()
          event.preventDefault()
          break
        case 9: /* tab */
          const end = this.element.selectionEnd
          this.element.setSelectionRange(end, end)
          this.suggestion = null
          event.preventDefault()
          break
      }
    }
  }

  removeSuggestion() {
    const textarea = this.element
    const start = textarea.selectionStart
    const end = textarea.selectionEnd

    if (start !== end) {
      const value = textarea.value
      textarea.value = value.substring(0, start) + value.substring(end)
      textarea.setSelectionRange(start, start)
    }
    this.suggestion = null
  }

  input(event) {
    this.handleAutocomplete()
    this.adjustHeight()
  }

  async handleAutocomplete() {
    const textarea = this.element
    const text = textarea.value
    const position = textarea.selectionStart

    if (this.changeLock) {
      return
    }
    if (this.backspaced) {
      this.backspaced = false
      return
    }
    // Scan backward to find the start of the current word, looking
    // for a `#` or `@` prefix that indicates a hashtag or mention.
    // Word boundaries include:
    // - any whitespace character (space, tab, newline, etc.)
    // - `undefined` (start of document)
    for (var i = 1; i < 64; i++) {
      let ch1 = text[position - i]
      let ch2 = text[position - i - 1]
      if ((ch1 === "#" || ch1 === "@") && (/\s/.test(ch2) || !ch2)) {
        break
      }
      if (/\s/.test(ch1) || !ch1) {
        i--
        break
      }
    }
    // Scan forward to find the end of the current word.
    for (var j = 0; j < 64; j++) {
      let ch = text[position + j]
      if (/\s/.test(ch) || !ch) {
        break
      }
    }
    const prefix = text.substring(position - i, position)
    const suffix = text.substring(position, position + j)
    if (!suffix && prefix.length > 2 && (prefix[0] === "#" || prefix[0] === "@")) {
      this.changeLock = true
      if (!this.suggestion || !this.suggestion.startsWith(prefix)) {
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
          let that = this
          fetch(url)
            .then(function(response) {
              return response.text()
            })
            .then(function(suggestion) {
              that.suggestion = `${prefix[0]}${suggestion}`
            })
            .catch(async (error) => {
              console.error('Autocomplete fetch failed:', error)
              that.suggestion = null
            })
        }
      }
      if (this.suggestion && this.suggestion.toLowerCase().startsWith(prefix.toLowerCase())) {
        const suggestionSuffix = this.suggestion.substring(prefix.length)
        const before = text.substring(0, position)
        const after = text.substring(position)
        textarea.value = before + suggestionSuffix + after
        textarea.setSelectionRange(position, position + suggestionSuffix.length)
        this.adjustHeight()
      }
      this.changeLock = false
    }
  }

  adjustHeight() {
    const element = this.element
    // reset height to get accurate scrollHeight
    element.style.height = 'auto'
    // set height to scrollHeight
    element.style.height = element.scrollHeight + 'px'
  }
}
