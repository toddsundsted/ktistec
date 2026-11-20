import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"

vi.mock("trix", () => ({
  default: {
    config: {
      attachments: {
        preview: {
          caption: { name: true, size: true },
        },
      },
    },
    controllers: {
      Level0InputController: {
        events: {
          keydown: vi.fn(),
        },
      },
      Level2InputController: {
        events: {
          keydown: vi.fn(),
        },
      },
    },
  },
}))

import TrixController from "../controllers/editor/trix_controller"

function makeAttachment({ url = "https://test.test/img.png", previewURL = null, alt = null, focalPoint = null } = {}) {
  const attributes = { alt, focalPoint }
  return {
    getURL: vi.fn().mockReturnValue(url),
    getPreviewURL: vi.fn().mockReturnValue(previewURL),
    getAttribute: vi.fn((name) => attributes[name]),
    setAttributes: vi.fn(),
  }
}

describe("TrixController", () => {
  let controller
  let modal

  function saveImageAndReadFocalPoint(attachment) {
    controller.saveImage()
    return attachment.setAttributes.mock.calls[0][0].focalPoint
  }

  beforeEach(() => {
    controller = Object.create(TrixController.prototype)
    controller.createImageModal()
    modal = controller.imageModal
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  describe("the image modal", () => {
    it("is a dialog", () => {
      expect(modal.getAttribute("role")).toBe("dialog")
    })

    it("starts hidden", () => {
      expect(modal.getAttribute("aria-hidden")).toBe("true")
    })
  })

  describe("the attachment toolbar", () => {
    let attachment
    let toolbar

    beforeEach(() => {
      attachment = { ...makeAttachment(), isPreviewable: () => true }
      toolbar = document.createElement("div")
      controller.beforeToolbar({ attachment, toolbar })
    })

    it("has an Edit button that opens the image modal for the attachment", () => {
      vi.spyOn(controller, "showImageModal")

      toolbar.querySelector(".trix-button--image").click()

      expect(controller.showImageModal).toHaveBeenCalledWith(attachment)
    })
  })

  describe("opening the image modal", () => {
    it("opens", () => {
      controller.showImageModal(makeAttachment())

      expect(modal.getAttribute("aria-hidden")).toBe("false")
    })

    it("shows the image", () => {
      controller.showImageModal(makeAttachment({ url: "https://test.test/img.png" }))

      expect(modal.querySelector(".modal-frame img").src).toBe("https://test.test/img.png")
    })

    it("shows the local preview while the image uploads", () => {
      controller.showImageModal(makeAttachment({ url: null, previewURL: "blob:https://test.test/preview" }))

      expect(modal.querySelector(".modal-frame img").src).toBe("blob:https://test.test/preview")
    })

    it("shows the alt text", () => {
      controller.showImageModal(makeAttachment({ alt: "a sunset photo" }))

      expect(modal.querySelector("textarea").value).toBe("a sunset photo")
    })

    it("shows the existing focal point", () => {
      controller.showImageModal(makeAttachment({ focalPoint: [0.5, -0.5] }))

      const dot = modal.querySelector(".focal-point")
      expect([dot.style.left, dot.style.top]).toEqual(["75%", "75%"])
    })
  })

  describe("dragging the focal point", () => {
    let attachment
    let frame

    function pointer(type, clientX, clientY, button = 0) {
      frame.dispatchEvent(new PointerEvent(type, { clientX, clientY, button, bubbles: true }))
    }

    beforeEach(() => {
      attachment = makeAttachment()
      controller.showImageModal(attachment)
      frame = modal.querySelector(".modal-frame")
      frame.querySelector("img").getBoundingClientRect = () => ({ left: 100, top: 50, width: 200, height: 100 })
    })

    it("sets the focal point where the pointer goes down", () => {
      pointer("pointerdown", 150, 75)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([-0.5, 0.5])
    })

    it("ignores buttons other than the primary button", () => {
      pointer("pointerdown", 150, 75, 2)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0, 0])
    })

    it("keeps focus in the modal when the image is pressed", () => {
      const event = new MouseEvent("mousedown", { bubbles: true, cancelable: true })
      frame.dispatchEvent(event)

      expect(event.defaultPrevented).toBe(true)
    })

    it("does not let the browser drag the image", () => {
      expect(frame.querySelector("img").draggable).toBe(false)
    })

    it("follows the pointer while it is down", () => {
      pointer("pointerdown", 150, 75)
      pointer("pointermove", 250, 125)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0.5, -0.5])
    })

    it("stops following the pointer when it goes up", () => {
      pointer("pointerdown", 150, 75)
      pointer("pointerup", 150, 75)
      pointer("pointermove", 250, 125)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([-0.5, 0.5])
    })

    it("stops following the pointer when it is cancelled", () => {
      pointer("pointerdown", 150, 75)
      pointer("pointercancel", 150, 75)
      pointer("pointermove", 250, 125)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([-0.5, 0.5])
    })

    it("ignores the pointer after the modal reopens", () => {
      pointer("pointerdown", 150, 75)
      controller.showImageModal(attachment)
      pointer("pointermove", 250, 125)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0, 0])
    })

    it("ignores the pointer until the image has loaded", () => {
      frame.querySelector("img").getBoundingClientRect = () => ({ left: 0, top: 0, width: 0, height: 0 })

      pointer("pointerdown", 150, 75)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0, 0])
    })

    it("keeps the focal point within the image", () => {
      pointer("pointerdown", 9999, 500)

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([1, -1])
    })
  })

  describe("moving the focal point with the keyboard", () => {
    let attachment
    let dot

    function key(key) {
      const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })
      dot.dispatchEvent(event)
      return event
    }

    beforeEach(() => {
      attachment = makeAttachment()
      controller.showImageModal(attachment)
      dot = modal.querySelector(".focal-point")
    })

    it("is reachable with the keyboard", () => {
      expect(dot.tabIndex).toBe(0)
    })

    it("moves the focal point right", () => {
      key("ArrowRight")

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0.1, 0])
    })

    it("moves the focal point left", () => {
      key("ArrowLeft")

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([-0.1, 0])
    })

    it("moves the focal point up", () => {
      key("ArrowUp")

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0, 0.1])
    })

    it("moves the focal point down", () => {
      key("ArrowDown")

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0, -0.1])
    })

    it("moves the focal point in exact steps", () => {
      key("ArrowRight")
      key("ArrowRight")
      key("ArrowRight")

      expect(saveImageAndReadFocalPoint(attachment)).toEqual([0.3, 0])
    })

    it("does not scroll the page", () => {
      expect(key("ArrowDown").defaultPrevented).toBe(true)
    })

    it("lets other keys through", () => {
      expect(key("Tab").defaultPrevented).toBe(false)
    })
  })

  describe("saving", () => {
    let attachment

    beforeEach(() => {
      attachment = makeAttachment()
      controller.showImageModal(attachment)
      modal.querySelector("textarea").value = "  a sunset photo  "
    })

    it("saves the trimmed alt text", () => {
      controller.saveImage()

      expect(attachment.setAttributes.mock.calls[0][0].alt).toBe("a sunset photo")
    })

    it("closes the modal", () => {
      controller.saveImage()

      expect(modal.getAttribute("aria-hidden")).toBe("true")
    })
  })

  describe("cancelling", () => {
    it("closes the modal without saving", () => {
      const attachment = makeAttachment()
      controller.showImageModal(attachment)

      modal.querySelector(".modal-footer button:not(.primary)").click()

      expect(modal.getAttribute("aria-hidden")).toBe("true")
      expect(attachment.setAttributes).not.toHaveBeenCalled()
    })
  })
})
