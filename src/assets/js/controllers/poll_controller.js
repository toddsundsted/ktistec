import { Controller } from "@hotwired/stimulus"

/**
 * Enable/disable vote button based on poll option selection.
 #
 */
export default class extends Controller {
  static targets = ["voteForm", "voteButton"]

  connect() {
    this.updateVoteButton()
  }

  optionSelected() {
    this.updateVoteButton()
  }

  updateVoteButton() {
    const form = this.voteFormTarget
    const checkboxes = form.querySelectorAll('input[type="checkbox"]:checked')
    const radios = form.querySelectorAll('input[type="radio"]:checked')
    const selected = checkboxes.length + radios.length

    this.voteButtonTarget.disabled = (selected === 0)
  }
}
