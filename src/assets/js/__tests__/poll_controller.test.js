import { describe, expect, it, beforeEach } from "vitest"
import PollController from "../controllers/poll_controller"

describe("PollController", () => {
  let controller
  let form
  let voteButton

  beforeEach(() => {
    form = document.createElement("form")
    voteButton = document.createElement("button")
    voteButton.disabled = true

    controller = Object.create(PollController.prototype)
    controller.voteFormTarget = form
    controller.voteButtonTarget = voteButton
    controller.hasVoteButtonTarget = true
  })

  describe("updateVoteButton", () => {
    it("keeps vote button disabled when no options are selected", () => {
      controller.updateVoteButton()

      expect(voteButton.disabled).toBe(true)
    })

    it("enables vote button when a checkbox is checked", () => {
      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = true
      form.appendChild(checkbox)

      controller.updateVoteButton()

      expect(voteButton.disabled).toBe(false)
    })

    it("enables vote button when a radio button is selected", () => {
      const radio = document.createElement("input")
      radio.type = "radio"
      radio.checked = true
      form.appendChild(radio)

      controller.updateVoteButton()

      expect(voteButton.disabled).toBe(false)
    })

    it("disables vote button when a previously checked option is unchecked", () => {
      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = true
      form.appendChild(checkbox)
      controller.updateVoteButton()
      expect(voteButton.disabled).toBe(false)

      checkbox.checked = false
      controller.updateVoteButton()

      expect(voteButton.disabled).toBe(true)
    })
  })

  describe("optionSelected", () => {
    it("calls updateVoteButton", () => {
      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = true
      form.appendChild(checkbox)

      controller.optionSelected()

      expect(voteButton.disabled).toBe(false)
    })
  })
})
