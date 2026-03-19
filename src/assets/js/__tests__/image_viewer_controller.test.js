import { describe, expect, it, beforeEach } from "vitest"
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
})
