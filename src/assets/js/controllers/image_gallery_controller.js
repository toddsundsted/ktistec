import { Controller } from "@hotwired/stimulus"

import lightGallery from "lightgallery"
import lgZoom from "lightgallery/plugins/zoom"
import lgRotate from "lightgallery/plugins/rotate"
import "lightgallery/css/lightgallery.css"
import "lightgallery/css/lg-zoom.css"
import "lightgallery/css/lg-rotate.css"

// open up the lightGallery prototype to redefine the `addHtml` method
// to better support the captioning of images.
;(function (lg) {
  Object.getPrototypeOf(lg).addHtml = function(index) {
    let caption = null,
        $figure = null,
        $figcaption = null,
        $item = this.items[index],
        appendSubHtmlTo = this.settings.appendSubHtmlTo,
        $lgComponents = this.$lgComponents.firstElement,
        $subHtml = $lgComponents.querySelector(appendSubHtmlTo)

    if ($figure = $item.closest("figure")) {
      if ($figcaption = $figure.querySelector("figcaption")) {
        if ($figcaption.innerHTML.trim() !== "") {
          caption = $figcaption.innerHTML
        }
      }
    }
    if (!caption) {
      caption = $item.getAttribute("alt") || $item.getAttribute("title")
    }
    if ($subHtml && caption) {
      $subHtml.innerHTML = caption
    }
  }
})(lightGallery())

/**
 * lightGallery
 *
 * The embedded license key was purchased on 2021/08/19, is valid for
 * GPLv3 compatible usage, and is redistributable with this project
 * and GPLv3 compatible derivatives.
 *
 */
export default class extends Controller {
  connect() {
    this.lightGallery = lightGallery(
      this.element, {
        licenseKey: "946563C8-F1154141-B722911E-843E9729",
        selector: ".content .text img, .content img.attachment",
        download: false,
        plugins: [lgZoom, lgRotate],
        showZoomInOutIcons: true,
        actualSize: false,
      })
  }

  disconnect() {
    this.lightGallery.destroy()
  }
}
