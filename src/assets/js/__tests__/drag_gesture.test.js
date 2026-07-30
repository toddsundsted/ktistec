import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"

import DragGesture from "../lib/drag_gesture"

describe("DragGesture", () => {
  let element
  let child
  let other
  let gesture
  let handlers

  const pointer = (type, target, x, y, options = {}) => {
    const event = new Event(type, { cancelable: true, bubbles: true })
    Object.assign(
      event,
      { pointerId: 1, pointerType: "mouse", button: 0, clientX: x, clientY: y },
      options
    )
    target.dispatchEvent(event)
    return event
  }

  const attach = (press = () => child) => {
    handlers = {
      press: vi.fn(press),
      start: vi.fn(),
      move: vi.fn(),
      end: vi.fn(),
    }
    gesture = new DragGesture(element, handlers)
    gesture.attach()
  }

  beforeEach(() => {
    Element.prototype.setPointerCapture = function () {}
    Element.prototype.releasePointerCapture = function () {}
    Element.prototype.hasPointerCapture = function () { return false }
    element = document.createElement("div")
    child = document.createElement("span")
    other = document.createElement("span")
    element.appendChild(child)
    element.appendChild(other)
    document.body.appendChild(element)
    vi.useFakeTimers()
  })

  afterEach(() => {
    gesture?.detach()
    gesture = null
    vi.useRealTimers()
    document.body.innerHTML = ""
  })

  describe("taking hold", () => {
    it("calls the press handler", () => {
      attach()
      pointer("pointerdown", child, 0, 0)

      expect(handlers.press).toHaveBeenCalled()
    })

    it("ignores a press the handler declines", () => {
      attach(() => null)
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 100, 0)

      expect(gesture.target).toBeNull()
      expect(handlers.start).not.toHaveBeenCalled()
    })

    it("ignores a secondary mouse button", () => {
      attach()
      pointer("pointerdown", child, 0, 0, { button: 2 })

      expect(handlers.press).not.toHaveBeenCalled()
    })

    it("captures the pointer on the element rather than the target", () => {
      attach()
      const captured = vi.spyOn(element, "setPointerCapture")
      pointer("pointerdown", child, 0, 0)

      expect(captured).toHaveBeenCalledWith(1)
    })
  })

  describe("a mouse", () => {
    it("arms once the pointer travels far enough", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)

      expect(handlers.start).toHaveBeenCalledWith(child)
    })

    it("arms once and then reports every move", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      pointer("pointermove", element, 20, 0)

      expect(handlers.start).toHaveBeenCalledTimes(1)
      expect(handlers.move).toHaveBeenCalledTimes(2)
    })

    it("does not arm before the pointer travels far enough", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 2, 2)

      expect(handlers.start).not.toHaveBeenCalled()
      expect(handlers.move).not.toHaveBeenCalled()
    })

    it("does not arm on a delay", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      vi.advanceTimersByTime(1000)

      expect(handlers.start).not.toHaveBeenCalled()
    })
  })

  describe("a pen", () => {
    const pen = { pointerType: "pen" }

    it("arms on travel", () => {
      attach()
      pointer("pointerdown", child, 0, 0, pen)
      pointer("pointermove", element, 10, 0, pen)

      expect(handlers.start).toHaveBeenCalledWith(child)
    })

    it("does not arm before the pointer travels far enough", () => {
      attach()
      pointer("pointerdown", child, 0, 0, pen)
      pointer("pointermove", element, 2, 2, pen)

      expect(handlers.start).not.toHaveBeenCalled()
    })

    it("does not arm on a delay", () => {
      attach()
      pointer("pointerdown", child, 0, 0, pen)
      vi.advanceTimersByTime(1000)

      expect(handlers.start).not.toHaveBeenCalled()
    })
  })

  describe("a touch", () => {
    const touch = { pointerType: "touch" }

    it("does not arm before the delay elapses", () => {
      attach()
      pointer("pointerdown", child, 0, 0, touch)
      vi.advanceTimersByTime(200)
      pointer("pointermove", element, 100, 0, touch)

      expect(handlers.start).not.toHaveBeenCalled()
    })

    it("arms once the delay elapses", () => {
      attach()
      pointer("pointerdown", child, 0, 0, touch)
      vi.advanceTimersByTime(250)

      expect(handlers.start).toHaveBeenCalledWith(child)
    })

    it("does not arm if the press is released", () => {
      attach()
      pointer("pointerdown", child, 0, 0, touch)
      pointer("pointerup", element, 0, 0, touch)
      vi.advanceTimersByTime(250)

      expect(handlers.start).not.toHaveBeenCalled()
    })

    it("does not arm on travel alone", () => {
      attach()
      pointer("pointerdown", child, 0, 0, touch)
      pointer("pointermove", element, 100, 100, touch)

      expect(handlers.start).not.toHaveBeenCalled()
    })
  })

  describe("ending", () => {
    it("reports a release that never became a drag", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointerup", element, 0, 0)

      expect(handlers.end).toHaveBeenCalledWith(child, { dragged: false, cancelled: false })
    })

    it("reports a cancelled drag", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      pointer("pointercancel", element, 10, 0)

      expect(handlers.end).toHaveBeenCalledWith(child, { dragged: true, cancelled: true })
    })

    it("reports a drop", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      pointer("pointerup", element, 10, 0)

      expect(handlers.end).toHaveBeenCalledWith(child, { dragged: true, cancelled: false })
    })

    it("ignores a release that follows no press", () => {
      attach()
      pointer("pointerup", element, 0, 0)

      expect(handlers.end).not.toHaveBeenCalled()
    })

    it("releases the pointer capture", () => {
      attach()
      Element.prototype.hasPointerCapture = function () { return true }
      const released = vi.spyOn(element, "releasePointerCapture")
      pointer("pointerdown", child, 0, 0)
      pointer("pointerup", element, 0, 0)

      expect(released).toHaveBeenCalledWith(1)
    })

    it("forgets the drag", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      pointer("pointerup", element, 10, 0)
      pointer("pointermove", element, 20, 0)

      expect(handlers.move).toHaveBeenCalledTimes(1)
    })
  })

  describe("a second pointer", () => {
    const second = { pointerId: 2, pointerType: "touch" }

    it("does not take hold while a press is in progress", () => {
      attach((event) => event.target)
      pointer("pointerdown", child, 0, 0)
      pointer("pointerdown", other, 50, 0, second)

      expect(handlers.press).toHaveBeenCalledTimes(1)
      expect(gesture.target).toEqual(child)
    })

    it("keeps reporting the first pointer's moves", () => {
      attach((event) => event.target)
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      pointer("pointerdown", other, 50, 0, second)
      pointer("pointermove", element, 20, 0)

      expect(handlers.move).toHaveBeenCalledTimes(2)
      expect(handlers.move).toHaveBeenLastCalledWith(child, expect.anything())
    })

    it("arms once the first press is over", () => {
      attach((event) => event.target)
      pointer("pointerdown", child, 0, 0)
      pointer("pointerup", element, 0, 0)
      pointer("pointerdown", other, 50, 0)
      pointer("pointermove", element, 60, 0)

      expect(handlers.start).toHaveBeenCalledWith(other)
    })

    describe("once the first pointer has the drag", () => {
      const arm = () => {
        attach((event) => event.target)
        pointer("pointerdown", child, 0, 0)
        pointer("pointermove", element, 10, 0)
        pointer("pointerdown", other, 50, 0, second)
        handlers.move.mockClear()
      }

      it("ignores the second pointer's moves", () => {
        arm()
        pointer("pointermove", element, 900, 900, second)

        expect(handlers.move).not.toHaveBeenCalled()
      })

      it("ignores the second pointer's release", () => {
        arm()
        pointer("pointerup", element, 900, 900, second)

        expect(handlers.end).not.toHaveBeenCalled()
      })

      it("ignores the second pointer's cancel", () => {
        arm()
        pointer("pointercancel", element, 900, 900, second)

        expect(handlers.end).not.toHaveBeenCalled()
      })

      it("reports the first pointer's own release", () => {
        arm()
        pointer("pointerup", element, 900, 900, second)
        handlers.end.mockClear()
        pointer("pointerup", element, 20, 0)

        expect(handlers.end).toHaveBeenCalledWith(child, { dragged: true, cancelled: false })
      })
    })
  })

  describe("Escape is pressed", () => {
    const keydown = (key = "Escape") => {
      const event = new KeyboardEvent("keydown", { key: key, bubbles: true, cancelable: true })
      document.dispatchEvent(event)
      return event
    }

    it("reports a cancelled drag", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      keydown()

      expect(handlers.end).toHaveBeenCalledWith(child, { dragged: true, cancelled: true })
    })

    it("keeps the browser from acting on the key", () => {
      attach()
      pointer("pointerdown", child, 0, 0)

      expect(keydown().defaultPrevented).toBe(true)
    })

    it("keeps the key from reaching any other listeners", () => {
      attach()
      const listener = vi.fn()
      document.addEventListener("keydown", listener)
      pointer("pointerdown", child, 0, 0)
      keydown()
      document.removeEventListener("keydown", listener)

      expect(listener).not.toHaveBeenCalled()
    })

    it("lets other keys through", () => {
      attach()
      pointer("pointerdown", child, 0, 0)

      expect(keydown("Enter").defaultPrevented).toBe(false)
      expect(handlers.end).not.toHaveBeenCalled()
    })

    it("lets the key through when no press is in progress", () => {
      attach()

      expect(keydown().defaultPrevented).toBe(false)
      expect(handlers.end).not.toHaveBeenCalled()
    })

    it("ignores the release", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      keydown()
      handlers.end.mockClear()
      pointer("pointermove", element, 20, 0)
      pointer("pointerup", element, 20, 0)

      expect(handlers.end).not.toHaveBeenCalled()
    })

  })

  describe("aborting", () => {
    it("reports that no press was in progress", () => {
      attach()

      expect(gesture.abort()).toBe(false)
    })

    it("reports that a press was in progress", () => {
      attach()
      pointer("pointerdown", child, 0, 0)

      expect(gesture.abort()).toBe(true)
    })

    it("does not report an end", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      gesture.abort()

      expect(handlers.end).not.toHaveBeenCalled()
    })

    it("forgets the press", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      gesture.abort()
      pointer("pointermove", element, 100, 0)
      pointer("pointerup", element, 100, 0)

      expect(handlers.start).not.toHaveBeenCalled()
      expect(handlers.move).not.toHaveBeenCalled()
      expect(handlers.end).not.toHaveBeenCalled()
    })

    it("releases the pointer capture", () => {
      attach()
      Element.prototype.hasPointerCapture = function () { return true }
      const released = vi.spyOn(element, "releasePointerCapture")
      pointer("pointerdown", child, 0, 0)
      gesture.abort()

      expect(released).toHaveBeenCalledWith(1)
    })

    it("does not arm the next press at the aborted press's deadline", () => {
      attach()
      pointer("pointerdown", child, 0, 0, { pointerType: "touch" })
      vi.advanceTimersByTime(150)
      gesture.abort()
      pointer("pointerdown", child, 0, 0, { pointerType: "touch" })
      vi.advanceTimersByTime(100)

      expect(handlers.start).not.toHaveBeenCalled()
    })

    it("arms a later press", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      gesture.abort()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)

      expect(handlers.start).toHaveBeenCalledWith(child)
    })
  })

  describe("detaching", () => {
    it("stops listening", () => {
      attach()
      gesture.detach()
      pointer("pointerdown", child, 0, 0)

      expect(handlers.press).not.toHaveBeenCalled()
    })

    it("releases the pointer capture of a drag", () => {
      attach()
      Element.prototype.hasPointerCapture = function () { return true }
      const released = vi.spyOn(element, "releasePointerCapture")
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      gesture.detach()

      expect(released).toHaveBeenCalledWith(1)
    })

    it("does not report an end", () => {
      attach()
      pointer("pointerdown", child, 0, 0)
      pointer("pointermove", element, 10, 0)
      gesture.detach()

      expect(handlers.end).not.toHaveBeenCalled()
    })
  })
})
