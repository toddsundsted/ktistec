import { Controller } from "stimulus"

export default class extends Controller {
  squelch(event) {
    event.preventDefault()
  }

  submit(event) {
    event.preventDefault()
    let input = event.target
    let form = input.closest("form")
    let action = input.getAttribute("action") || form.getAttribute("action")
    let method = form.getAttribute("method")
    let data = new FormData(form)
    let xhr = new XMLHttpRequest()
    xhr.open(method, action)
    xhr.setRequestHeader("Accept", "text/html")
    xhr.onload = function() {
      let status = xhr.status
      // detect redirect
      if (xhr.responseURL && (new URL(xhr.responseURL).pathname != action)) {
        Turbolinks.visit(xhr.responseURL)
      } else {
        let dom = new DOMParser().parseFromString(xhr.response, "text/html")
        let new_form = dom.getElementById(form.id)
        form.replaceWith(new_form)
        scrollTo(0, 0)
      }
    }
    xhr.send(data)
  }
}
