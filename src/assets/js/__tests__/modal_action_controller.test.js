import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"
import ModalActionController from "../controllers/modal_action_controller"

describe("ModalActionController", () => {
  let controller
  let triggerElement
  let form
  let modal
  let buttonOk
  let buttonCancel

  beforeEach(() => {
    form = document.createElement("form")
    form.submit = vi.fn()

    triggerElement = document.createElement("button")
    triggerElement.dataset.modal = "confirm"
    form.appendChild(triggerElement)

    modal = document.createElement("div")
    modal.className = "ui modal confirm"

    buttonOk = document.createElement("button")
    buttonOk.className = "ui button ok"
    modal.appendChild(buttonOk)

    buttonCancel = document.createElement("button")
    buttonCancel.className = "ui button cancel"
    modal.appendChild(buttonCancel)

    document.body.appendChild(form)
    document.body.appendChild(modal)

    controller = Object.create(ModalActionController.prototype)
    Object.defineProperty(controller, "element", {
      value: triggerElement,
      writable: true,
      configurable: true,
    })
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("prevents the default event action and shows the modal", () => {
    const event = { preventDefault: vi.fn() }

    controller.show(event)

    expect(event.preventDefault).toHaveBeenCalled()
    expect(modal.parentElement.classList.contains("active")).toBe(true)
    expect(document.body.classList.contains("dimmed")).toBe(true)
  })

  it("submits the form and hides the modal when ok is clicked", () => {
    const event = { preventDefault: vi.fn() }

    controller.show(event)
    buttonOk.click()

    expect(form.submit).toHaveBeenCalled()
    expect(modal.classList.contains("active")).toBe(false)
  })

  it("removes active/dimmed classes when cancel is clicked", () => {
    const event = { preventDefault: vi.fn() }

    controller.show(event)
    buttonCancel.click()

    expect(modal.classList.contains("active")).toBe(false)
    expect(document.body.classList.contains("dimmed")).toBe(false)
  })
})
