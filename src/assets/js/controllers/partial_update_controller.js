import { Controller } from "stimulus"

export default class extends Controller {
  submit(event) {
    let old_element = this.element
    let form = event.target.closest("form")
    let data = new FormData(form)
    let xhr = new XMLHttpRequest()
    xhr.open(form.getAttribute("method"), form.getAttribute("action"))
    xhr.setRequestHeader("Accept", "text/html")
    xhr.onload = function() {
      let document = new DOMParser().parseFromString(xhr.response, "text/html")
      let new_element = document.getElementById(old_element.id)
      if (new_element) {
        old_element.replaceWith(new_element)
      } else {
        old_element.remove()
      }
    }
    xhr.send(data)
  }
}
