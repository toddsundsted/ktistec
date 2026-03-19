import { describe, expect, it, beforeEach } from "vitest"
import MarkdownController from "../controllers/editor/markdown_controller"

describe("MarkdownController", () => {
  let controller
  let element

  beforeEach(() => {
    element = document.createElement("textarea")
    document.body.appendChild(element)

    controller = Object.create(MarkdownController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
      writable: true,
      configurable: true,
    })
  })

  it("sets element height to its scrollHeight", () => {
    Object.defineProperty(element, "scrollHeight", {
      value: 200,
      configurable: true,
    })

    controller.adjustHeight()

    expect(element.style.height).toBe("200px")
  })

  it("initializes suggestion, changeLock, and backspaced on connect", () => {
    controller.connect()

    expect(controller.suggestion).toBeNull()
    expect(controller.changeLock).toBe(false)
    expect(controller.backspaced).toBe(false)
  })

  it("sets backspaced to true on backspace when suggestion exists", () => {
    controller.suggestion = "#hello"
    controller.backspaced = false

    controller.handleKeydown({ keyCode: 8, preventDefault: () => {} })

    expect(controller.backspaced).toBe(true)
  })
})
