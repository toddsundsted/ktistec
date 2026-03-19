import { describe, expect, it, beforeEach, vi } from "vitest"
import CheckboxSubmitController from "../controllers/checkbox_submit_controller"

describe("CheckboxSubmitController", () => {
  let controller
  let element

  beforeEach(() => {
    element = document.createElement("div")
    document.body.appendChild(element)

    controller = Object.create(CheckboxSubmitController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
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
})
