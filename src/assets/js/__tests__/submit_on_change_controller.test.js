import { describe, expect, it, beforeEach, afterEach } from "vitest"
import { Application } from "@hotwired/stimulus"
import { morphChildren } from "@hotwired/turbo"
import SubmitOnChangeController from "../controllers/submit_on_change_controller"

describe("SubmitOnChangeController", () => {
  const markup = `
    <form data-controller="submit-on-change">
      <input type="checkbox" data-action="change->submit-on-change#change">
    </form>
  `

  let application
  let submits

  const change = () => {
    document.querySelector("input[type=checkbox]").dispatchEvent(new Event("change"))
  }

  beforeEach(async () => {
    document.body.innerHTML = markup
    application = Application.start()
    application.register("submit-on-change", SubmitOnChangeController)
    await Promise.resolve()
    submits = 0
    document.querySelector("form").addEventListener("submit", (event) => {
      event.preventDefault()
      submits += 1
    })
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  it("submits the form when the input changes", () => {
    change()

    expect(submits).toBe(1)
  })

  describe("after a morph", () => {
    beforeEach(async () => {
      const replacement = document.createElement("body")
      replacement.innerHTML = markup
      morphChildren(document.body, replacement)
      await Promise.resolve()
    })

    it("submits the form when the input changes", () => {
      change()

      expect(submits).toBe(1)
    })
  })
})
