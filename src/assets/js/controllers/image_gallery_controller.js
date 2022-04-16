import { Controller } from "stimulus"

import lightGallery from "lightgallery"
import "lightgallery/css/lightgallery.css"

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
    lightGallery(
      this.element, {
        licenseKey: "946563C8-F1154141-B722911E-843E9729",
        selector: ".content .text img, .content img.attachment, .content .text video, .content video.attachment",
        download: false
      })
  }
}
