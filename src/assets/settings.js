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
    restore: null,
    load: null,
    fetch: null,
    patch: null
  }
})

function initialize() {
  FilePond.create(
    document.querySelector("form[action='/settings/actor'] input[type='file'][name='image']"), {
      acceptedFileTypes: ["image/png", "image/jpeg", "image/gif"],
      imageResizeTargetWidth: 1400,
      imageResizeTargetHeight: 700,
  })
  FilePond.create(
    document.querySelector("form[action='/settings/actor'] input[type='file'][name='icon']"), {
      acceptedFileTypes: ["image/png", "image/jpeg", "image/gif"],
      imageResizeTargetWidth: 240,
      imageResizeTargetHeight: 240
  })
}

document.addEventListener("turbolinks:load", initialize)

initialize()
