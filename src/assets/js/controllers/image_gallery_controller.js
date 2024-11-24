import { Controller } from "@hotwired/stimulus"

import lightGallery from "lightgallery"
import lgZoom from "lightgallery/plugins/zoom"
import lgRotate from "lightgallery/plugins/rotate"
import "lightgallery/css/lightgallery.css"
import "lightgallery/css/lg-zoom.css"
import "lightgallery/css/lg-rotate.css"

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
        selector: ".content .text img, .content img.attachment, .content .text video, .content video.attachment",
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
