/**
 * FilePond
 */
import * as FilePond from "filepond"
import FilePondPluginFileValidateType from "filepond-plugin-file-validate-type"
import FilePondPluginImageResize from "filepond-plugin-image-resize"
import FilePondPluginImageTransform from "filepond-plugin-image-transform"
import FilePondPluginImagePreview from "filepond-plugin-image-preview"
import "filepond/dist/filepond.css"
import "filepond-plugin-image-preview/dist/filepond-plugin-image-preview.css"

FilePond.registerPlugin(
  FilePondPluginFileValidateType,
  FilePondPluginImageResize,
  FilePondPluginImageTransform,
  FilePondPluginImagePreview
)
FilePond.setOptions({
  allowPaste: false,
  server: {
    process: {
      url: "/uploads",
      headers: {"X-CSRF-Token": Ktistec.csrf, "Accept": "text/plain"}
    },
    revert: {
      url: "/uploads",
      headers: {"X-CSRF-Token": Ktistec.csrf}
    },
    restore: {
      url: ""
    },
    load: {
      url: ""
    },
    fetch: null,
    patch: null
  }
})

function initialize() {
  function enable(selector, width, height) {
    let input = document.querySelector(selector)
    if (input) {
      let files = []
      let value = input.getAttribute("value")
      if (value) {
        files.push({
          source: new URL(input.getAttribute("value")).pathname,
          options: {
            type: "local"
          }
        })
      }
      FilePond.create(input, {
        acceptedFileTypes: ["image/png", "image/jpeg", "image/gif"],
        imageResizeTargetWidth: width,
        imageResizeTargetHeight: height,
        files: files
      })
    }
  }
  enable("form[action='/settings/actor'] input[type='file'][name='image']", 1400, 700)
  enable("form[action='/settings/actor'] input[type='file'][name='icon']", 240, 240)
  enable("form[action='/settings/service'] input[type='file'][name='image']", 630, 630)
}

document.addEventListener("turbo:load", initialize)
document.addEventListener("turbo:render", initialize)

initialize()
