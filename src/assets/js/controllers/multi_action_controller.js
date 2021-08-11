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
        Turbo.visit(xhr.responseURL)
      } else {
        // don't cache because the form will usually contain error messages
        if (document.querySelectorAll("meta[name='turbo-cache-control']").length < 1) {
          let head = document.querySelector("head")
          let meta = document.createElement("meta")
          meta.setAttribute("name", "turbo-cache-control")
          meta.setAttribute("content", "no-cache")
          head.appendChild(meta)
        }
        let new_dom = new DOMParser().parseFromString(xhr.response, "text/html")
        let new_form = new_dom.getElementById(form.id)
        form.replaceWith(new_form)
        scrollTo(0, 0)
      }
    }
    xhr.send(data)
  }
}
