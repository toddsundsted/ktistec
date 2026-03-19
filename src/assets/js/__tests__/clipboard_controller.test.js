import { describe, expect, it, beforeEach, vi } from "vitest"
import ClipboardController from "../controllers/clipboard_controller"

describe("ClipboardController", () => {
  let controller
  let element

  beforeEach(() => {
    element = document.createElement("i")
    element.className = "copy icon"

    Object.defineProperty(navigator, "clipboard", {
      value: { writeText: vi.fn().mockResolvedValue(undefined) },
      writable: true,
      configurable: true,
    })

    controller = Object.create(ClipboardController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
      writable: true,
      configurable: true,
    })
    controller.textValue = "Hello, World!"
  })

  it("copies text to clipboard on click", async () => {
    await controller.click({})

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith("Hello, World!")
  })

  it("changes icon class from copy to check on click", async () => {
    await controller.click({})

    expect(element.className).toContain("check")
    expect(element.className).not.toContain("copy")
  })

  it("sets icon color to green on click", async () => {
    await controller.click({})

    // jsdom normalizes hex colors to rgb() format
    expect(element.style.color).toBe("rgb(33, 186, 69)")
  })
})
