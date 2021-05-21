"use strict"

import $ from "jquery"

/**
 * TurboLinks
 */
const Turbolinks = require("turbolinks")
Turbolinks.start()

/**
 * Stimulus
 */
import { Application } from "stimulus"
import { definitionsFromContext } from "stimulus/webpack-helpers"

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

/**
 * lightGallery
 */
import "lightgallery"
import "lightgallery/dist/css/lightgallery.css"

$(document).on("turbolinks:load", function() {
  $(".ui.feed .event")
    .find(".content .text img")
    .each(function () {
      let $this = $(this)
      $this.attr("data-src", $this.attr("src"))
    })
    .end()
    .lightGallery({
      selector: ".content img[data-src]",
      download: false
    })
})

// power share and like buttons
$(document).on("submit", "section form:has(.iconic.button):has(.share.icon,.star.icon)", function (e) {
  e.preventDefault()
  let $form = $(this)
  let $section = $("section")
  $.ajax({
    type: $form.attr("method"),
    url: $form.attr("action"),
    data: $form.serialize(),
    dataType: "html",
    success: function (data) {
      let $data = $($.parseHTML(data)).find("section")
      $section.replaceWith($data)
    }
  })
})

// modal popup for dangrous actions
$(document).on("click", ".dangerous.button[data-modal]", function (e) {
  e.preventDefault()
  let $this = $(this)
  let $form = $this.closest("form")
  let modal = $this.data("modal")
  $(".ui.modal." + modal)
    .modal({
      onApprove: function() {
        $form.submit()
      }
    })
    .modal("show")
})

// refresh actors with missing icon images
$(document).on("turbolinks:load", function () {
  $(".ui.feed .event img[data-actor-id]").on("error", function() {
    let $this = $(this)
    $this.replaceWith('<i class="user icon"></i>')
    $.ajax({
      type: "POST",
      url: `/remote/actors/${$this.data("actor-id")}/refresh`,
      headers: {
        "X-CSRF-Token": Ktistec.csrf
      }
    })
  })
})
