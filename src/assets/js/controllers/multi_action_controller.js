import { Controller } from "stimulus"

export default class extends Controller {
  squelch(event) {
    event.preventDefault()
  }

  submit(event) {
    event.preventDefault()
    let input = event.target
    let form = input.closest("form")
    let data = new FormData(form)
    let xhr = new XMLHttpRequest()
    xhr.open(form.getAttribute("method"), input.getAttribute("action"))
    xhr.setRequestHeader("Accept", "text/html")
    xhr.onload = function() {
      let location = xhr.responseURL
      Turbolinks.visit(location || window.location)
    }
    xhr.send(data)
  }
}
