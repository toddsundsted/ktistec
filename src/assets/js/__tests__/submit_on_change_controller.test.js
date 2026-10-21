import { describe, expect, it, beforeEach, vi } from "vitest"
import SubmitOnChangeController from "../controllers/submit_on_change_controller"

describe("SubmitOnChangeController", () => {
  let controller
  let element
  let fallback

  beforeEach(() => {
    element = document.createElement("div")
    document.body.appendChild(element)
    fallback = document.createElement("button")
    element.appendChild(fallback)

    controller = Object.create(SubmitOnChangeController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
      writable: true,
      configurable: true,
    })
    Object.defineProperty(controller, "fallbackTargets", {
      value: [fallback],
      writable: true,
      configurable: true,
    })
    controller.connect()
  })

  it("appends a hidden submit input on connect", () => {
    const inputs = element.querySelectorAll('input[type="submit"]')

    expect(inputs.length).toBe(1)
    expect(inputs[0].style.display).toBe("none")
  })

  it("stores the hidden input on the controller instance", () => {
    expect(controller.input).toBeDefined()
    expect(controller.input.type).toBe("submit")
  })

  it("clicks the hidden submit button when change is called", () => {
    const clickSpy = vi.spyOn(controller.input, "click")

    controller.change({})

    expect(clickSpy).toHaveBeenCalled()
  })

  it("removes the hidden submit input on disconnect", () => {
    controller.disconnect()

    expect(element.querySelectorAll('input[type="submit"]').length).toBe(0)
  })

  it("hides its fallback buttons", () => {
    expect(fallback.style.display).toBe("none")
  })
})
