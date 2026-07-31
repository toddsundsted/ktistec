import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"
import ImageViewerController from "../controllers/image_viewer_controller"

describe("ImageViewerController", () => {
  let controller

  beforeEach(() => {
    controller = Object.create(ImageViewerController.prototype)
  })

  it("escapes HTML entities", () => {
    expect(controller.escapeHtml('<script>alert("xss")</script>')).toBe(
      '&lt;script&gt;alert("xss")&lt;/script&gt;'
    )
  })

  it("returns true for a viewer image in .extra.text", () => {
    const content = document.createElement("div")
    content.className = "content"
    Object.defineProperty(controller, "element", {
      value: content,
      writable: true,
      configurable: true,
    })

    const extraText = document.createElement("div")
    extraText.className = "extra text"
    const img = document.createElement("img")
    extraText.appendChild(img)
    content.appendChild(extraText)

    expect(controller.isViewerImage(img)).toBe(true)
  })

  it("opens the viewer when a qualifying image is clicked", () => {
    const content = document.createElement("div")
    content.className = "content"
    Object.defineProperty(controller, "element", {
      value: content,
      writable: true,
      configurable: true,
    })

    let openedWith = null
    controller.openViewer = (img) => { openedWith = img }
    controller.isViewerImage = () => true

    const img = document.createElement("img")
    let defaultPrevented = false
    const event = { target: img, preventDefault: () => { defaultPrevented = true } }
    controller.handleClick(event)

    expect(openedWith).toBe(img)
    expect(defaultPrevented).toBe(true)
  })

  describe("swiping", () => {
    let modal
    let backdrop
    let controls
    let content

    const touch = (type, x, y, target = content) => {
      const event = new Event(type, { cancelable: true, bubbles: true })
      const points = [{ clientX: x, clientY: y, identifier: 0, target: target }]
      event.touches = (type === "touchend" || type === "touchcancel") ? [] : points
      event.changedTouches = points
      target.dispatchEvent(event)
      return event
    }

    const pinch = (type, target = content) => {
      const event = new Event(type, { cancelable: true, bubbles: true })
      const points = [
        { clientX: 0, clientY: 0, identifier: 0, target: target },
        { clientX: 40, clientY: 0, identifier: 1, target: target },
      ]
      event.touches = points
      event.changedTouches = points
      target.dispatchEvent(event)
      return event
    }

    const drag = (dx, dy) => {
      touch("touchstart", 200, 200)
      touch("touchmove", 200 + dx, 200 + dy)
    }

    const swipe = (dx, dy) => {
      drag(dx, dy)
      touch("touchend", 200 + dx, 200 + dy)
    }

    const button = (className) => {
      const element = document.createElement("button")
      element.className = className
      controls.appendChild(element)
      return element
    }

    beforeEach(() => {
      vi.useFakeTimers()

      modal = document.createElement("div")
      modal.className = "image-viewer-modal"

      backdrop = document.createElement("div")
      backdrop.className = "image-viewer-modal__backdrop"
      modal.appendChild(backdrop)

      controls = document.createElement("div")
      controls.className = "image-viewer-modal__controls"
      modal.appendChild(controls)

      content = document.createElement("div")
      content.className = "image-viewer-modal__content"

      const wrapper = document.createElement("div")
      wrapper.className = "image-viewer-modal__image-wrapper"
      content.appendChild(wrapper)
      modal.appendChild(content)

      document.body.appendChild(modal)

      controller.modal = modal
      controller.backdropElement = backdrop
      controller.imageWrapper = wrapper
      controller.prevButton = button("image-viewer-modal__prev")
      controller.nextButton = button("image-viewer-modal__next")
      controller.closeButton = button("image-viewer-modal__close")
      controller.collection = ["a", "b", "c"]
      controller.currentIndex = 1
      controller.zoomLevel = 1.0
      controller.panX = 0
      controller.panY = 0
      controller.isPanning = false
      controller.swipeX = 0
      controller.swipeY = 0
      controller.swipeAxis = null
      controller.isSwiping = false

      controller.navigatePrev = vi.fn()
      controller.navigateNext = vi.fn()
      controller.closeModal = vi.fn()

      controller.initSwipeListeners()
    })

    afterEach(() => {
      vi.useRealTimers()
      document.body.innerHTML = ""
    })

    describe("arming", () => {
      it("ignores a touch that has not travelled far enough", () => {
        drag(5, 5)

        expect(controller.swipeAxis).toBeNull()
        expect(controller.swipeX).toBe(0)
      })

      it("locks to the horizontal axis", () => {
        drag(30, 10)

        expect(controller.swipeAxis).toBe("horizontal")
      })

      it("locks to the vertical axis", () => {
        drag(10, 30)

        expect(controller.swipeAxis).toBe("vertical")
      })

      it("keeps the horizontal axis when the finger arcs away", () => {
        drag(30, 0)
        touch("touchmove", 240, 400)

        expect(controller.swipeAxis).toBe("horizontal")
      })

      it("ignores the off-axis travel of an arcing swipe", () => {
        drag(30, 0)
        touch("touchmove", 240, 400)

        expect(controller.swipeY).toBe(0)
      })

      it("keeps the vertical axis when the finger arcs away", () => {
        drag(0, 30)
        touch("touchmove", 400, 240)

        expect(controller.swipeAxis).toBe("vertical")
      })

      it("ignores the off-axis travel of an arcing close swipe", () => {
        drag(0, 30)
        touch("touchmove", 400, 240)

        expect(controller.swipeX).toBe(0)
      })

      it("claims the gesture once armed", () => {
        touch("touchstart", 200, 200)
        const event = touch("touchmove", 300, 200)

        expect(event.defaultPrevented).toBe(true)
      })

      it("leaves an unarmed gesture to the browser", () => {
        touch("touchstart", 200, 200)
        const event = touch("touchmove", 205, 200)

        expect(event.defaultPrevented).toBe(false)
      })

      it("ignores a touch that starts on the controls", () => {
        touch("touchstart", 200, 200, controller.closeButton)
        touch("touchmove", 400, 200, controller.closeButton)

        expect(controller.swipeAxis).toBeNull()
      })

      it("ignores a touch while the image is zoomed", () => {
        controller.zoomLevel = 2.0
        drag(100, 0)

        expect(controller.swipeAxis).toBeNull()
      })
    })

    describe("tracking", () => {
      it("moves the image with the finger", () => {
        drag(-100, 0)

        expect(controller.swipeX).toBe(-100)
      })

      it("transforms the image wrapper", () => {
        drag(-100, 0)

        expect(controller.imageWrapper.style.transform).toContain("translate(-100px, 0px)")
      })

      it("resists when there is no previous image", () => {
        controller.currentIndex = 0
        drag(100, 0)

        expect(controller.swipeX).toBe(25)
      })

      it("resists when there is no next image", () => {
        controller.currentIndex = 2
        drag(-100, 0)

        expect(controller.swipeX).toBe(-25)
      })

      it("does not resist a close swipe", () => {
        drag(0, 200)

        expect(controller.swipeY).toBe(200)
      })
    })

    describe("committing", () => {
      it("navigates to the previous image", () => {
        swipe(100, 0)

        expect(controller.navigatePrev).toHaveBeenCalled()
      })

      it("navigates to the next image", () => {
        swipe(-100, 0)

        expect(controller.navigateNext).toHaveBeenCalled()
      })

      it("does not navigate on a swipe that stops short", () => {
        swipe(-40, 0)

        expect(controller.navigateNext).not.toHaveBeenCalled()
      })

      it("does not navigate past the end of the collection", () => {
        controller.currentIndex = 2
        swipe(-300, 0)

        expect(controller.navigateNext).not.toHaveBeenCalled()
      })

      it("closes on a swipe up", () => {
        swipe(0, -100)

        expect(controller.closeModal).toHaveBeenCalled()
      })

      it("closes on a swipe down", () => {
        swipe(0, 100)

        expect(controller.closeModal).toHaveBeenCalled()
      })

      it("does not close on a swipe that stops short", () => {
        swipe(0, 60)

        expect(controller.closeModal).not.toHaveBeenCalled()
      })

      it("leaves the image where the finger left it while closing", () => {
        swipe(0, 120)

        expect(controller.imageWrapper.style.transform).toContain("translate(0px, 120px)")
      })

      it("leaves the backdrop faded while closing", () => {
        swipe(0, 120)

        expect(Number(backdrop.style.opacity)).toBeCloseTo(0.65)
      })

    })

    describe("feedback", () => {
      it("highlights the control the swipe will trigger", () => {
        drag(-100, 0)

        expect(controller.nextButton.classList.contains("is-swipe-target")).toBe(true)
      })

      it("does not highlight the control the swipe moves away from", () => {
        drag(-100, 0)

        expect(controller.prevButton.classList.contains("is-swipe-target")).toBe(false)
      })

      it("withdraws the highlight when the finger falls back", () => {
        drag(-100, 0)
        touch("touchmove", 190, 200)

        expect(controller.nextButton.classList.contains("is-swipe-target")).toBe(false)
      })

      it("withholds the highlight when there is no next image", () => {
        controller.currentIndex = 2
        drag(-300, 0)

        expect(controller.nextButton.classList.contains("is-swipe-target")).toBe(false)
      })

      it("highlights the close button on a committed close swipe", () => {
        drag(0, 120)

        expect(controller.closeButton.classList.contains("is-swipe-target")).toBe(true)
      })

      it("fades the backdrop as the close swipe travels", () => {
        drag(0, 120)

        expect(Number(backdrop.style.opacity)).toBeCloseTo(0.65)
      })

      it("hands the backdrop back to the stylesheet when the finger falls back", () => {
        drag(0, 120)
        touch("touchmove", 200, 210)
        touch("touchend", 200, 210)

        expect(backdrop.style.opacity).toBe("")
      })

      it("leaves the backdrop alone during a navigation swipe", () => {
        drag(-100, 0)

        expect(backdrop.style.opacity).toBe("")
      })

      it("clears the highlight when the swipe ends", () => {
        swipe(-100, 0)

        expect(controller.nextButton.classList.contains("is-swipe-target")).toBe(false)
      })
    })

    describe("settling", () => {
      it("returns the image when the swipe stops short", () => {
        swipe(-40, 0)

        expect(controller.swipeX).toBe(0)
      })

      it("animates the return", () => {
        swipe(-40, 0)

        expect(controller.imageWrapper.classList.contains("is-settling")).toBe(true)
      })

      it("restores the zoom transition once settled", () => {
        swipe(-40, 0)
        vi.advanceTimersByTime(200)

        expect(controller.imageWrapper.classList.contains("is-settling")).toBe(false)
      })

      it("stops settling when the next swipe arms inside the window", () => {
        swipe(-40, 0)
        vi.advanceTimersByTime(100)
        drag(-40, 0)

        expect(controller.imageWrapper.classList.contains("is-settling")).toBe(false)
      })

      it("returns the image when the touch is cancelled", () => {
        drag(-100, 0)
        touch("touchcancel", 100, 200)

        expect(controller.swipeX).toBe(0)
      })

      it("does not navigate when the touch is cancelled", () => {
        drag(-100, 0)
        touch("touchcancel", 100, 200)

        expect(controller.navigateNext).not.toHaveBeenCalled()
      })

      it("lets go of the swipe when a second finger lands", () => {
        drag(-100, 0)
        pinch("touchstart")

        expect(controller.isSwiping).toBe(false)
      })

      it("lets go of the swipe when a second finger joins the drag", () => {
        drag(-100, 0)
        pinch("touchmove")

        expect(controller.isSwiping).toBe(false)
      })
    })
  })
})
