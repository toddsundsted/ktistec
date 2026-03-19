import { describe, expect, it, beforeEach } from "vitest"
import HasContentController from "../controllers/has_content_controller"

describe("HasContentController", () => {
  let controller
  let input
  let button

  beforeEach(() => {
    input = document.createElement("textarea")
    button = document.createElement("button")

    controller = Object.create(HasContentController.prototype)
    controller.inputTarget = input
    controller.buttonTargets = [button]
    controller.hasSaveDraftButtonTarget = false
    Object.defineProperty(controller, "element", {
      value: document.createElement("div"),
      writable: true,
      configurable: true,
    })
  })

  it("adds 'disabled' class to buttons when input is empty", () => {
    input.value = ""

    controller._check(null)

    expect(button.classList.contains("disabled")).toBe(true)
  })

  it("removes 'disabled' class from buttons when input has content", () => {
    input.value = "some content"
    button.classList.add("disabled")

    controller._check(null)

    expect(button.classList.contains("disabled")).toBe(false)
  })
})
