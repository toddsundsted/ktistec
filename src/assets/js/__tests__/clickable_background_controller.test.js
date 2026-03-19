import { describe, expect, it, beforeEach, vi } from "vitest"
import ClickableBackgroundController from "../controllers/clickable_background_controller"

describe("ClickableBackgroundController", () => {
  let controller

  beforeEach(() => {
    controller = Object.create(ClickableBackgroundController.prototype)
    controller.hrefValue = "/posts/123"
    controller.moved = false

    global.Turbo = { visit: vi.fn() }
  })

  it("resets moved to false on mousedown", () => {
    controller.moved = true

    controller.mousedown({})

    expect(controller.moved).toBe(false)
  })

  it("sets moved to true on mousemove", () => {
    controller.mousemove({})

    expect(controller.moved).toBe(true)
  })

  it("navigates using Turbo.visit when background is clicked", () => {
    controller.click({ target: document.createElement("div") })

    expect(Turbo.visit).toHaveBeenCalledWith("/posts/123")
  })
})
