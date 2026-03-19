import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"
import IconLoadErrorController from "../controllers/icon_load_error_controller"

describe("IconLoadErrorController", () => {
  let controller
  let element

  beforeEach(() => {
    element = document.createElement("div")
    document.body.appendChild(element)

    controller = Object.create(IconLoadErrorController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
      writable: true,
      configurable: true,
    })

    global.Ktistec = { auth: false, csrf: "test-token" }
  })

  afterEach(() => {
    document.body.removeChild(element)
    delete global.Ktistec
  })

  it("registers an error event listener on connect", () => {
    const addEventListenerSpy = vi.spyOn(element, "addEventListener")

    controller.connect()

    expect(addEventListenerSpy).toHaveBeenCalledWith(
      "error",
      expect.any(Function),
      true
    )
  })

  it("replaces a broken actor icon with the fallback image", () => {
    controller.connect()

    const img = document.createElement("img")
    img.dataset.actorId = "123"
    element.appendChild(img)

    img.dispatchEvent(new Event("error", { bubbles: false }))

    const replacement = element.querySelector("img")
    expect(replacement).not.toBe(img)
    expect(replacement.getAttribute("src")).toBe("/images/avatars/fallback.png")
    expect(replacement.dataset.actorId).toBe("123")
    expect(replacement.className).toContain("avatar")
  })

  it("does not replace images without data-actor-id", () => {
    controller.connect()

    const img = document.createElement("img")
    img.src = "/some/image.png"
    element.appendChild(img)

    img.dispatchEvent(new Event("error", { bubbles: false }))

    expect(element.querySelector("img")).toBe(img)
  })

  it("sends a refresh request when authenticated", () => {
    global.Ktistec = { auth: true, csrf: "test-csrf-token" }

    let xhrInstance = null
    global.XMLHttpRequest = function () {
      xhrInstance = {
        open: vi.fn(),
        setRequestHeader: vi.fn(),
        send: vi.fn(),
      }
      return xhrInstance
    }

    controller.connect()

    const img = document.createElement("img")
    img.dataset.actorId = "456"
    element.appendChild(img)

    img.dispatchEvent(new Event("error", { bubbles: false }))

    expect(xhrInstance).toBeDefined()
    expect(xhrInstance.open).toHaveBeenCalledWith(
      "POST",
      "/remote/actors/456/refresh",
      true
    )
    expect(xhrInstance.setRequestHeader).toHaveBeenCalledWith(
      "X-CSRF-Token",
      "test-csrf-token"
    )
    expect(xhrInstance.send).toHaveBeenCalled()
  })

  it("does not send a refresh request when not authenticated", () => {
    global.Ktistec = { auth: false }

    let xhrCreated = false
    global.XMLHttpRequest = function () {
      xhrCreated = true
      return { open: vi.fn(), setRequestHeader: vi.fn(), send: vi.fn() }
    }

    controller.connect()

    const img = document.createElement("img")
    img.dataset.actorId = "789"
    element.appendChild(img)

    img.dispatchEvent(new Event("error", { bubbles: false }))

    expect(xhrCreated).toBe(false)
  })
})
