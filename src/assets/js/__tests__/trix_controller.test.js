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

describe("TrixController", () => {
  let controller

  beforeEach(() => {
    controller = Object.create(TrixController.prototype)
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("creates and appends the alt text modal to the document body", () => {
    controller.createAltTextModal()

    const modal = document.querySelector(".trix-alt-text-modal")
    expect(modal).toBeTruthy()
    expect(modal.getAttribute("aria-hidden")).toBe("true")
    expect(modal.getAttribute("role")).toBe("dialog")
  })

  it("shows the alt text modal by setting aria-hidden to false", () => {
    controller.createAltTextModal()
    const attachment = { getAttribute: vi.fn().mockReturnValue("") }

    controller.showAltTextModal(attachment)

    expect(controller.altTextModal.getAttribute("aria-hidden")).toBe("false")
  })

  it("saves alt text to the attachment and hides the modal", () => {
    controller.createAltTextModal()
    const attachment = {
      getAttribute: vi.fn().mockReturnValue(""),
      setAttributes: vi.fn(),
    }
    controller.currentAttachment = attachment
    controller.altTextModal.setAttribute("aria-hidden", "false")
    controller.altTextModal.querySelector("textarea").value = "a sunset photo"

    controller.saveAltText()

    expect(attachment.setAttributes).toHaveBeenCalledWith({ alt: "a sunset photo" })
    expect(controller.altTextModal.getAttribute("aria-hidden")).toBe("true")
  })
})
