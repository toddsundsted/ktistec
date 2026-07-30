import { Controller } from "@hotwired/stimulus"

import { moveTerm, serialize, splitTerms } from "../lib/criteria_terms"
import { indexLabels, renderLabel } from "../lib/term_label"
import { insertionIndex, measureSlots } from "../lib/drag_geometry"
import { flip } from "../lib/flip"
import DragGesture from "../lib/drag_gesture"

// Progressively enhances a feed's criteria textarea into a list of
// removable term labels plus an entry for adding more labels.
//
// Terms are kept verbatim.
//
export default class extends Controller {
  static targets = ["textarea"]
  static values = { placeholder: String }

  connect() {
    this.terms = splitTerms(this.textareaTarget.value)
    this.focusIndex = 0

    this.dragIndex = null
    this.slots = []
    this.grabOffset = null
    this.dragUndo = null
    this.pressedLabel = null

    this.textareaTarget.parentElement.querySelectorAll(".ui.labels").forEach((field) => field.remove())
    this.textareaTarget.parentElement.querySelectorAll(".criteria-status").forEach((status) => status.remove())

    this.field = document.createElement("div")
    this.field.className = "ui labels"

    this.entry = document.createElement("input")
    this.entry.type = "text"
    this.entry.placeholder = this.placeholderValue
    this.entry.setAttribute("aria-label", this.placeholderValue)

    this.status = document.createElement("div")
    this.status.className = "criteria-status"
    this.status.setAttribute("role", "status")
    this.status.setAttribute("aria-live", "polite")

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

    this.drag = new DragGesture(this.field, {
      press: (event) => this._press(event),
      start: (label) => this._dragStart(label),
      move: (label, event) => this._dragMove(label, event),
      end: (label, outcome) => this._dragEnd(label, outcome),
    })
    this.drag.attach()

    this.field.appendChild(this.entry)
    this.textareaTarget.insertAdjacentElement("afterend", this.field)
    this.field.insertAdjacentElement("afterend", this.status)
    this.textareaTarget.style.display = "none"

    this.element.classList.add("enhanced")

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
    this.drag.detach()

    if (!this.field.isConnected) {
      return
    }

    this.entry.removeEventListener("keydown", this.keydownHandler)
    this.entry.removeEventListener("blur", this.blurHandler)
    this.entry.removeEventListener("paste", this.pasteHandler)
    this.field.removeEventListener("click", this.clickHandler)
    this.field.removeEventListener("keydown", this.fieldKeydownHandler)

    this.field.remove()
    this.status.remove()
    this.textareaTarget.style.display = null

    this.element.classList.remove("enhanced")
  }

  _labels() {
    return Array.from(this.field.querySelectorAll(".ui.label"))
  }

  _labelAt(index) {
    return this._labels()[index]
  }

  _render() {
    const repress = this.drag.target && !this.drag.dragging && this.dragIndex < this.terms.length

    if (!repress) {
      this._abortDrag()
    }

    this._labels().forEach((label) => label.remove())

    if (this.focusIndex >= this.terms.length) {
      this.focusIndex = Math.max(0, this.terms.length - 1)
    }

    this.terms.forEach((term) => this.field.insertBefore(renderLabel(term), this.entry))

    indexLabels(this._labels(), this.focusIndex)
    this.textareaTarget.value = serialize(this.terms)

    if (repress) {
      this._repress()
    }
  }

  _repress() {
    const label = this._labelAt(this.dragIndex)
    label.classList.add("pressed")
    this.dragUndo.terms = this.terms.slice()
    this.drag.retarget(label)
  }

  _commit(value = this.entry.value) {
    if (value.trim() === "") {
      this.entry.value = ""
      return
    }
    this.terms = this.terms.concat(splitTerms(value))
    this.entry.value = ""
    this._render()
  }

  _remove(index, { edit = false, keep = false } = {}) {
    const [term] = this.terms.splice(index, 1)
    if (index < this.focusIndex) {
      this.focusIndex -= 1
    }
    this._render()
    if (edit) {
      this.entry.value = term
    }
    if (keep) {
      this._focusTerm(this.focusIndex)
    } else {
      this.entry.focus()
    }
  }

  _move(from, to) {
    if (from < 0 || from >= this.terms.length) {
      return
    }
    const index = Math.max(0, Math.min(to, this.terms.length - 1))
    if (index === from) {
      return
    }
    const term = this.terms[from]
    this.terms = moveTerm(this.terms, from, index)
    this.focusIndex = index
    this._render()
    this._labelAt(index)?.focus()
    this._announce(term, index)
  }

  _focusTerm(index) {
    if (!this.terms.length) {
      this.entry.focus()
      return
    }
    this.focusIndex = Math.max(0, Math.min(index, this.terms.length - 1))
    indexLabels(this._labels(), this.focusIndex)
    this._labelAt(this.focusIndex)?.focus()
  }

  _announce(term, index) {
    this.status.textContent = `Moved ${term} to position ${index + 1} of ${this.terms.length}`
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
      this._remove(this.terms.length - 1, { edit: true })
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

  _fieldKeydown(event) {
    const label = this._ownLabel(event.target)
    if (!label) {
      return
    }

    const index = Number(label.dataset.index)

    if (event.altKey && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
      event.preventDefault()
      this._move(index, event.key === "ArrowUp" ? index - 1 : index + 1)
    } else if (!event.altKey && (event.key === "ArrowLeft" || event.key === "ArrowRight")) {
      event.preventDefault()
      this._focusTerm(index + (event.key === "ArrowLeft" ? -1 : 1))
    } else if (event.key === "Home") {
      event.preventDefault()
      this._focusTerm(0)
    } else if (event.key === "End") {
      event.preventDefault()
      this._focusTerm(this.terms.length - 1)
    } else if (event.key === "Delete" || event.key === "Backspace") {
      event.preventDefault()
      this._remove(index, { keep: true })
    }
  }

  _click(event) {
    const icon = event.target.closest(".delete.icon")
    if (icon) {
      event.preventDefault()
      this._remove(Number(icon.dataset.index))
    } else if (event.target === this.field && !this.pressedLabel) {
      this.entry.focus()
    }
  }

  _ownLabel(node) {
    const label = node.closest(".ui.label")
    return label && label.parentElement === this.field ? label : null
  }

  _press(event) {
    this.pressedLabel = null
    if (event.target.closest(".delete.icon")) {
      return null
    }
    const label = this._ownLabel(event.target)
    if (!label) {
      return null
    }
    this.pressedLabel = label
    const rect = label.getBoundingClientRect()

    this.dragIndex = Number(label.dataset.index)
    this.grabOffset = { x: event.clientX - rect.left, y: event.clientY - rect.top }
    this.dragUndo = {
      terms: this.terms.slice(),
      index: this.dragIndex,
    }

    label.classList.add("pressed")

    return label
  }

  _dragStart(label) {
    label.classList.add("dragging")
    this.slots = measureSlots(this._labels(), label)
  }

  _dragMove(label, event) {
    const index = insertionIndex(
      this.slots,
      event.clientX + window.scrollX,
      event.clientY + window.scrollY
    )
    if (index !== this.dragIndex) {
      this._slideTo(label, index)
    }
    this._track(label, event)
  }

  _slideTo(dragged, index) {
    const others = this._labels().filter((label) => label !== dragged)

    flip(others, () => {
      this.field.insertBefore(dragged, others[index] || this.entry)
      this.terms = moveTerm(this.terms, this.dragIndex, index)
      this.dragIndex = index
      this.focusIndex = index
      indexLabels(this._labels(), this.focusIndex)
      this.textareaTarget.value = serialize(this.terms)
    })
  }

  _track(label, event) {
    label.style.transform = ""
    const rect = label.getBoundingClientRect()
    const x = event.clientX - this.grabOffset.x - rect.left
    const y = event.clientY - this.grabOffset.y - rect.top
    label.style.transform = `translate(${x}px, ${y}px)`
  }

  _abortDrag() {
    if (!this.drag.abort()) {
      return
    }
    this.dragIndex = null
    this.grabOffset = null
    this.dragUndo = null
    this.slots = []
  }

  _dragEnd(pressed, { dragged, cancelled }) {
    const undo = this.dragUndo

    this._labels().forEach((label) => {
      label.classList.remove("dragging", "pressed")
      label.style.transform = ""
      label.style.transition = ""
    })

    this.dragIndex = null
    this.grabOffset = null
    this.dragUndo = null
    this.slots = []

    if (!dragged) {
      this._focusTerm(Number(pressed.dataset.index))
      return
    }

    if (cancelled) {
      if (undo) {
        this.terms = undo.terms
        this.focusIndex = undo.index
        this._render()
        this._labelAt(this.focusIndex)?.focus()
      }
      return
    }

    this._labelAt(this.focusIndex)?.focus()

    if (undo && this.focusIndex !== undo.index) {
      this._announce(this.terms[this.focusIndex], this.focusIndex)
    }
  }
}
