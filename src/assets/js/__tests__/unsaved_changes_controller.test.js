import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"

import UnsavedChangesController from "../controllers/unsaved_changes_controller"

describe("UnsavedChangesController", () => {
  let controller
  let form
  let input

  const connect = (value) => {
    input.value = value
    controller = Object.create(UnsavedChangesController.prototype)
    Object.defineProperty(controller, "element", { value: form, writable: true })
    Object.defineProperty(controller, "messageValue", { value: "Discard them?", writable: true })
    controller.connect()
  }

  const beforeVisit = () => {
    const event = new Event("turbo:before-visit", { cancelable: true })
    document.dispatchEvent(event)
    return event
  }

  const beforeUnload = () => {
    const event = new Event("beforeunload", { cancelable: true })
    window.dispatchEvent(event)
    return event
  }

  beforeEach(() => {
    form = document.createElement("form")
    input = document.createElement("input")
    input.type = "text"
    input.name = "name"
    form.appendChild(input)
    document.body.appendChild(form)
  })

  afterEach(() => {
    if (controller) {
      controller.disconnect()
    }
    document.body.innerHTML = ""
    vi.restoreAllMocks()
  })

  describe("serialize", () => {
    it("includes every named field", () => {
      const second = document.createElement("input")
      second.type = "text"
      second.name = "notes"
      second.value = "two"
      form.appendChild(second)
      connect("one")

      expect(controller.serialize()).toEqual("name=one&notes=two")
    })

    it("distinguishes states that would collide unescaped", () => {
      const second = document.createElement("input")
      second.type = "text"
      second.name = "any"
      second.value = "2&any=3"
      form.appendChild(second)
      connect("1")
      const baseline = controller.serialize()

      input.value = "1&any=2"
      second.value = "3"

      expect(controller.serialize()).not.toEqual(baseline)
    })

    it("includes a field written after connect", () => {
      connect("")
      const textarea = document.createElement("textarea")
      textarea.name = "any"
      textarea.value = "llm"
      form.appendChild(textarea)

      expect(controller.serialize()).toEqual("name=&any=llm")
    })
  })

  describe("changed", () => {
    it("is false when no field has been edited", () => {
      connect("one")

      expect(controller.changed()).toBe(false)
    })

    it("is true when a field has been edited", () => {
      connect("one")
      input.value = "two"

      expect(controller.changed()).toBe(true)
    })
  })

  describe("a Turbo visit", () => {
    it("is allowed when nothing has changed", () => {
      const confirmed = vi.spyOn(window, "confirm").mockReturnValue(false)
      connect("one")

      expect(beforeVisit().defaultPrevented).toBe(false)
      expect(confirmed).not.toHaveBeenCalled()
    })

    it("is cancelled when there are changes and the prompt is declined", () => {
      vi.spyOn(window, "confirm").mockReturnValue(false)
      connect("one")
      input.value = "two"

      expect(beforeVisit().defaultPrevented).toBe(true)
    })

    it("is allowed when there are changes and the prompt is accepted", () => {
      vi.spyOn(window, "confirm").mockReturnValue(true)
      connect("one")
      input.value = "two"

      expect(beforeVisit().defaultPrevented).toBe(false)
    })

    it("asks with the configured message", () => {
      const confirmed = vi.spyOn(window, "confirm").mockReturnValue(true)
      connect("one")
      input.value = "two"
      beforeVisit()

      expect(confirmed).toHaveBeenCalledWith("Discard them?")
    })
  })

  describe("leaving the page", () => {
    it("is allowed when nothing has changed", () => {
      connect("one")

      expect(beforeUnload().defaultPrevented).toBe(false)
    })

    it("is confirmed when there are changes", () => {
      connect("one")
      input.value = "two"

      expect(beforeUnload().defaultPrevented).toBe(true)
    })
  })

  describe("submitting the form", () => {
    it("is not treated as leaving the page", () => {
      vi.spyOn(window, "confirm").mockReturnValue(false)
      connect("one")
      input.value = "two"
      form.dispatchEvent(new Event("submit"))

      expect(controller.changed()).toBe(false)
      expect(beforeVisit().defaultPrevented).toBe(false)
    })

    it("requires confirmation again if the form is edited after saving", () => {
      vi.spyOn(window, "confirm").mockReturnValue(false)
      connect("one")
      form.dispatchEvent(new Event("submit"))
      input.value = "three"

      expect(beforeVisit().defaultPrevented).toBe(true)
    })
  })

  describe("disconnect", () => {
    it("stops warning", () => {
      vi.spyOn(window, "confirm").mockReturnValue(false)
      connect("one")
      input.value = "two"
      controller.disconnect()

      expect(beforeVisit().defaultPrevented).toBe(false)
      expect(beforeUnload().defaultPrevented).toBe(false)

      controller = null
    })
  })
})
