import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  show(event) {
    event.preventDefault()

    let form = this.element.closest("form")
    let modal = document.querySelector(`.ui.modal.${this.element.dataset.modal}`)
    let buttonOk = modal.querySelector(".ui.button.ok")
    let buttonCancel = modal.querySelector(".ui.button.cancel")
    let body = document.querySelector("body")

    // dynamically update modal text content
    Object.keys(this.element.dataset).forEach(key => {
      if (key.startsWith('modal') && key.length > 5) {
        // convert camelCase to kebab-case and remove prefix
        let className = key.replace(/([A-Z])/g, '-$1').toLowerCase().slice(6)
        let elements = modal.querySelectorAll(`.${className}`)
        elements.forEach(element => {
          element.textContent = this.element.dataset[key]
        })
      }
    })

    if (!modal.parentElement.classList.contains("dimmer")) {
      let div = document.createElement("div")
      div.classList.add("ui")
      div.classList.add("dimmer")
      div.append(modal)
      body.append(div)
    }

    let dimmer = modal.parentElement

    let okFn = function () {
      teardownFn()
      form.submit()
    }
    let escapeFn = function (event) {
      if (event.key == "Escape") {
        teardownFn()
      }
    }
    let cancelFn = function () {
      teardownFn()
    }

    let teardownFn = function () {
      buttonOk.removeEventListener("click", okFn)
      buttonCancel.removeEventListener("click", cancelFn)
      document.removeEventListener("keydown", escapeFn)
      dimmer.removeEventListener("click", cancelFn)

      modal.classList.remove("active")
      dimmer.classList.remove("active")
      body.classList.remove("dimmed")
    }

    buttonOk.addEventListener("click", okFn)
    buttonCancel.addEventListener("click", cancelFn)
    document.addEventListener("keydown", escapeFn)
    dimmer.addEventListener("click", cancelFn)

    setTimeout(() => modal.classList.add("active"), 20)
    dimmer.classList.add("active")
    body.classList.add("dimmed")
  }
}
