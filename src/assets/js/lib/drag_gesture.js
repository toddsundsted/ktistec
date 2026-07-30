// Turns pointer events into a drag.

const DRAG_THRESHOLD = 5

const TOUCH_DELAY = 250

const armsOnRest = (event) => event.pointerType === "touch"

export default class DragGesture {
  constructor(element, handlers) {
    this.element = element
    this.handlers = handlers

    this.target = null
    this.pointerId = null
    this.dragging = false
    this.origin = null
    this.timer = null

    this.downHandler = (event) => this._down(event)
    this.moveHandler = (event) => this._move(event)
    this.upHandler = (event) => this._finish(event, false)
    this.cancelHandler = (event) => this._finish(event, true)
    this.keydownHandler = (event) => this._keydown(event)
  }

  attach() {
    this.element.addEventListener("pointerdown", this.downHandler)
    this.element.addEventListener("pointermove", this.moveHandler)
    this.element.addEventListener("pointerup", this.upHandler)
    this.element.addEventListener("pointercancel", this.cancelHandler)
    document.addEventListener("keydown", this.keydownHandler, true)
  }

  detach() {
    this.abort()
    this.element.removeEventListener("pointerdown", this.downHandler)
    this.element.removeEventListener("pointermove", this.moveHandler)
    this.element.removeEventListener("pointerup", this.upHandler)
    this.element.removeEventListener("pointercancel", this.cancelHandler)
    document.removeEventListener("keydown", this.keydownHandler, true)
  }

  // Ends the press without reporting it, because what it took hold of
  // is gone.
  //
  abort() {
    this._clearTimer()
    if (!this.target) {
      return false
    }
    this._release()
    this.target = null
    this.pointerId = null
    this.dragging = false
    this.origin = null
    return true
  }

  // Takes hold of the element that replaced the one it was holding.
  //
  retarget(target) {
    this.target = target
  }

  _down(event) {
    if (this.target) {
      return
    }
    if (event.pointerType === "mouse" && event.button !== 0) {
      return
    }
    const target = this.handlers.press(event)
    if (!target) {
      return
    }

    this.target = target
    this.pointerId = event.pointerId
    this.dragging = false
    this.origin = { x: event.clientX, y: event.clientY }

    this.element.setPointerCapture(event.pointerId)

    if (!armsOnRest(event)) {
      return
    }
    this.timer = setTimeout(() => this._arm(), TOUCH_DELAY)
  }

  _arm() {
    this._clearTimer()
    if (!this.target) {
      return
    }
    this.dragging = true
    this.handlers.start(this.target)
  }

  _move(event) {
    if (!this._ours(event)) {
      return
    }

    if (!this.dragging) {
      const dx = event.clientX - this.origin.x
      const dy = event.clientY - this.origin.y
      if (armsOnRest(event) || Math.hypot(dx, dy) < DRAG_THRESHOLD) {
        return
      }
      this._arm()
    }

    this.handlers.move(this.target, event)
  }

  _keydown(event) {
    if (event.key !== "Escape" || !this.target) {
      return
    }
    event.preventDefault()
    event.stopPropagation()
    this._end(true)
  }

  _finish(event, cancelled) {
    if (!this._ours(event)) {
      return
    }
    this._end(cancelled)
  }

  _end(cancelled) {
    const target = this.target
    const dragged = this.dragging

    this._clearTimer()
    this._release()
    this.target = null
    this.pointerId = null
    this.dragging = false
    this.origin = null

    this.handlers.end(target, { dragged: dragged, cancelled: cancelled })
  }

  _ours(event) {
    return event.pointerId === this.pointerId
  }

  _release() {
    if (this.pointerId !== null && this.element.hasPointerCapture(this.pointerId)) {
      this.element.releasePointerCapture(this.pointerId)
    }
  }

  _clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
}
