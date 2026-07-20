import { Controller } from "@hotwired/stimulus"

// Progressively enhances a feed's criteria textarea into a list of
// removable term labels plus an entry for adding more labels.
//
// Features:
// 1. Enter commits the entry; a multi-line paste commits every line
// 2. Backspace returns the removed term to the entry for editing
// 3. The delete icon removes a term
//
// Terms are kept verbatim.
//
export default class extends Controller {
  static targets = ["textarea"]
  static values = { placeholder: String }

  connect() {
    this.terms = this.splitTerms(this.textareaTarget.value)

    this.textareaTarget.parentElement.querySelectorAll(".ui.labels").forEach((field) => field.remove())

    this.field = document.createElement("div")
    this.field.className = "ui labels"

    this.entry = document.createElement("input")
    this.entry.type = "text"
    this.entry.placeholder = this.placeholderValue
    this.entry.setAttribute("aria-label", this.placeholderValue)

    this.keydownHandler = (event) => this._keydown(event)
    this.blurHandler = () => this._commit()
    this.pasteHandler = (event) => this._paste(event)
    this.clickHandler = (event) => this._click(event)
    this.fieldKeydownHandler = (event) => this._fieldKeydown(event)
    this.beforeCacheHandler = () => this._teardown()

    this.entry.addEventListener("keydown", this.keydownHandler)
    this.entry.addEventListener("blur", this.blurHandler)
    this.entry.addEventListener("paste", this.pasteHandler)
    this.field.addEventListener("click", this.clickHandler)
    this.field.addEventListener("keydown", this.fieldKeydownHandler)
    document.addEventListener("turbo:before-cache", this.beforeCacheHandler)

    this.field.appendChild(this.entry)
    this.textareaTarget.insertAdjacentElement("afterend", this.field)
    this.textareaTarget.style.display = "none"

    this._render()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCacheHandler)
    this._teardown()
  }

  // Turbo snapshots the page before Stimulus disconnects. Without
  // this the cache would hold the injected field and a hidden
  // textarea, and a restoration visit would enhance an
  // already-enhanced form. Idempotent.
  //
  _teardown() {
    if (!this.field.isConnected) {
      return
    }

    this.entry.removeEventListener("keydown", this.keydownHandler)
    this.entry.removeEventListener("blur", this.blurHandler)
    this.entry.removeEventListener("paste", this.pasteHandler)
    this.field.removeEventListener("click", this.clickHandler)
    this.field.removeEventListener("keydown", this.fieldKeydownHandler)

    this.field.remove()
    this.textareaTarget.style.display = null
  }

  // Splits stored text into terms.
  //
  splitTerms(text) {
    return text.replace(/\r\n/g, "\n").split("\n").filter((line) => line.trim() !== "")
  }

  // Joins terms back into stored text.
  //
  serialize(terms) {
    return terms.join("\n")
  }

  // Infers a term's type from its raw first character.
  //
  classifyTerm(term) {
    if (term.startsWith("#")) {
      return "hashtag"
    }
    if (term.startsWith("@") || /^https?:\/\//i.test(term)) {
      return "mention"
    }
    return "keyword"
  }

  // Splits a term into alternating runs of whitespace and everything
  // else, so that whitespace can be rendered as dots.
  //
  segmentTerm(term) {
    const runs = []
    for (const text of term.match(/\s+|\S+/g) || []) {
      runs.push({ space: /\s/.test(text[0]), text: text })
    }
    return runs
  }

  // Whether a term's whitespace is leading or trailing.
  //
  hasBoundarySpace(term) {
    return /^\s|\s$/.test(term)
  }

  _render() {
    this.field.querySelectorAll(".ui.label").forEach((label) => label.remove())

    this.terms.forEach((term, index) => {
      const label = document.createElement("span")
      label.className = `ui label ${this.classifyTerm(term)}`
      if (this.hasBoundarySpace(term)) {
        label.classList.add("boundary-space")
        label.title = JSON.stringify(term)
      }

      this.segmentTerm(term).forEach((run) => {
        if (run.space) {
          const space = document.createElement("span")
          space.className = "space"
          space.textContent = "·".repeat(run.text.length)
          label.appendChild(space)
        } else {
          label.appendChild(document.createTextNode(run.text))
        }
      })

      const icon = document.createElement("i")
      icon.className = "delete icon"
      icon.dataset.index = index
      icon.tabIndex = 0
      icon.setAttribute("role", "button")
      icon.setAttribute("aria-label", `Remove ${term}`)
      label.appendChild(icon)

      this.field.insertBefore(label, this.entry)
    })

    this.textareaTarget.value = this.serialize(this.terms)
  }

  // takes the text explicitly because an input silently strips the
  // newlines a multi-line paste depends on
  _commit(value = this.entry.value) {
    if (value.trim() === "") {
      this.entry.value = ""
      return
    }
    this.terms = this.terms.concat(this.splitTerms(value))
    this.entry.value = ""
    this._render()
  }

  _remove(index, edit) {
    const [term] = this.terms.splice(index, 1)
    this._render()
    if (edit) {
      this.entry.value = term
    }
    this.entry.focus()
  }

  _keydown(event) {
    if (event.isComposing) {
      return
    }

    if (event.key === "Enter") {
      event.preventDefault()
      this._commit()
    } else if (event.key === "Backspace" && this.entry.value === "" && this.terms.length) {
      event.preventDefault()
      this._remove(this.terms.length - 1, true)
    }
  }

  _paste(event) {
    const text = (event.clipboardData || window.clipboardData).getData("text")
    if (!/[\r\n]/.test(text)) {
      return
    }
    event.preventDefault()
    this._commit(this.entry.value + text)
  }

  // the delete icon is focusable, so it has to answer the keyboard too
  _fieldKeydown(event) {
    const icon = event.target.closest(".delete.icon")
    if (icon && (event.key === "Enter" || event.key === " ")) {
      event.preventDefault()
      this._remove(Number(icon.dataset.index), false)
    }
  }

  _click(event) {
    const icon = event.target.closest(".delete.icon")
    if (icon) {
      event.preventDefault()
      this._remove(Number(icon.dataset.index), false)
    } else if (event.target === this.field) {
      this.entry.focus()
    }
  }
}
