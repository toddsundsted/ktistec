"use strict"

/**
 * Turbo
 */
import {StreamActions, session} from "@hotwired/turbo"

StreamActions["no-op"] = function () {
  // no-op is a keep-alive action
}

/**
 * Stimulus
 */
import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"

const application = Application.start()
const context = require.context("./controllers", true, /\.js$/)
application.load(definitionsFromContext(context))

/**
 * Trix
 */
import Trix from "trix"
import "trix/dist/trix.css"

// toolbar
Trix.config.toolbar.getDefaultHTML = function() {
  let {lang} = Trix.config
  return `
  <div class="trix-toolbar-container">
    <div class="ui compact mini icon menu">
      <button class="item" tabindex="-1" data-trix-attribute="bold" data-trix-key="b" title="${lang.bold}"><i class="bold icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="italic" data-trix-key="i" title="${lang.italic}"><i class="italic icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="strike" title="${lang.strike}"><i class="strikethrough icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="code" title="${lang.code}"><i class="code icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="sup" title="Superscript"><i class="superscript icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="sub" title="Subscript"><i class="subscript icon"></i></button>
      <button class="item" tabindex="-1" data-trix-attribute="href" data-trix-action="link" data-trix-key="k"title="${lang.link}"><i class="linkify icon"></i></button>
    </div>
    <div class="ui compact mini icon menu">
        <button class="item" tabindex="-1" data-trix-attribute="heading1" title="${lang.heading1}"><i class="heading icon"></i></button>
        <button class="item" tabindex="-1" data-trix-attribute="quote" title="${lang.quote}"><i class="quote right icon"></i></button>
        <button class="item" tabindex="-1" data-trix-attribute="pre" title="${lang.code}"><i class="code icon"></i></button>
        <button class="item" tabindex="-1" data-trix-attribute="bullet" title="${lang.bullets}"><i class="list ul icon"></i></button>
        <button class="item" tabindex="-1" data-trix-attribute="number" title="${lang.numbers}"><i class="list ol icon"></i></button>
        <button class="item" tabindex="-1" data-trix-action="decreaseNestingLevel" title="${lang.outdent}"><i class="outdent icon"></i></button>
        <button class="item" tabindex="-1" data-trix-action="increaseNestingLevel" title="${lang.indent}"><i class="indent icon"></i></button>
    </div>
    <div class="ui compact mini icon menu">
      <button class="item" tabindex="-1" data-trix-action="attachFiles" title="${lang.attachFiles}"><i class="paperclip icon"></i></button>
    </div>
    <div class="ui compact mini icon menu">
      <button class="item" tabindex="-1" data-trix-action="undo" data-trix-key="z" title="${lang.undo}"><i class="undo icon"></i></button>
      <button class="item" tabindex="-1" data-trix-action="redo" data-trix-key="shift+z" title="${lang.redo}"><i class="redo icon"></i></button>
    </div>
  </div>
  <div class="trix-dialogs" data-trix-dialogs>
    <div class="trix-dialog" data-trix-dialog="href" data-trix-dialog-attribute="href">
      <div class="trix-dialog__link-fields">
        <input type="url" name="href" class="trix-input trix-input--dialog" placeholder="${lang.urlPlaceholder}" aria-label="${lang.url}" required data-trix-input>
        <div class="trix-button-group">
          <input type="button" class="trix-button trix-button--dialog" value="${lang.link}" data-trix-method="setAttribute">
          <input type="button" class="trix-button trix-button--dialog" value="${lang.unlink}" data-trix-method="removeAttribute">
        </div>
      </div>
    </div>
  </div>
  `
}

delete Trix.config.blockAttributes.code
Trix.config.blockAttributes.pre = { tagName: "pre", terminal: true, text: { plaintext: true } }
Trix.config.textAttributes.code = { tagName: "code", inheritable: true }
Trix.config.textAttributes.sub = { tagName: "sub", inheritable: true }
Trix.config.textAttributes.sup = { tagName: "sup", inheritable: true }

// prevent morphing of the editor, lightgallery, and images. each has
// client state that will be lost if the page is refreshed/morphed.
// see: https://github.com/hotwired/turbo-rails/issues/533
// see: https://github.com/hotwired/turbo/issues/1083

addEventListener("turbo:before-morph-element", (event) => {
  const { target } = event
  if (target.tagName == "DIV" && target.classList.contains("lg-container")) {
    event.preventDefault()
  } else if (target.tagName == "IMG" && target.dataset.lgId) {
    event.preventDefault()
  }
})

// monitor the stream sources on the page. if any are closed, remove
// them, which ensures they are recreated when the page refreshes.

// to prevent the monitor from spamming the server during maintenance
// or other downtime events, delay the start of the check for 6 * 10
// seconds. then check every 10 seconds. after refreshing the page,
// again delay the start of the check for 6 * 10 seconds. note that
// this code will not be reloaded if the page is refreshed.

;(function () {
  let counter = 0
  let closed = false
  let checking = false

  function checkConnectivity(callback) {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)

    fetch(window.location.origin, { method: 'HEAD', cache: 'no-store', signal: controller.signal })
      .then(response => {
        clearTimeout(timeoutId)
        callback(response.status >= 200)
      })
      .catch(error => {
        clearTimeout(timeoutId)
        callback(false)
      })
  }

  setInterval(function () {
    counter = counter + 1
    document.querySelectorAll('turbo-stream-source').forEach(function (turboStreamSource) {
      if (turboStreamSource.streamSource.readyState == 2) { // closed
        turboStreamSource.remove()
        closed = true
      }
    })

    if (counter > 5 && closed && !checking) {
      checking = true
      checkConnectivity(function (isOnline) {
        if (isOnline) {
          document.body.classList.remove('offline');
          console.debug("counter", counter, "closed", closed, "|", "refreshing", window.location.href)
          session.refresh(window.location.href)
          counter = 0
          closed = false
          checking = false
        } else {
          document.body.classList.add('offline');
          console.debug("counter", counter, "closed", closed, "|", "server unreachable, waiting to refresh", window.location.href)
          checking = false
        }
      })
    }
  }, 10000)
})()
