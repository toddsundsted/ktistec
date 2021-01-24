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
      url: '/uploads',
      headers: {'X-CSRF-Token': Ktistec.csrf, 'Accept': 'text/plain'}
    },
    revert: {
      url: '/uploads',
      headers: {'X-CSRF-Token': Ktistec.csrf}
    },
    restore: null,
    load: null,
    fetch: null,
    patch: null
  }
})

!!(function($) {
  $(document).on('submit', 'section form:has(.iconic.button):has(.share.icon,.star.icon)', function (e) {
    e.preventDefault()
    let $form = $(this)
    let $section = $('section')
    $.ajax({
      type: $form.attr('method'),
      url: $form.attr('action'),
      data: $form.serialize(),
      dataType: 'html',
      success: function (data) {
        let $data = $($.parseHTML(data)).find('section')
        $section.replaceWith($data)
      }
    })
  })
  $(document).on('click', '.dangerous.button', function (e) {
    e.preventDefault()
    let $this = $(this)
    let $form = $this.closest('form')
    let modal = $this.data('modal')
    $('.ui.modal.' + modal)
      .modal({
        onApprove: function() {
          $form.submit()
        }
      })
      .modal('show')
  })
  $(document).on("turbolinks:load", function () {
    FilePond.create(
      document.querySelector('form[action="/settings"] input[type="file"][name="image"]'), {
        acceptedFileTypes: ['image/png', 'image/jpeg', 'image/gif'],
        imageResizeTargetWidth: 1400,
        imageResizeTargetHeight: 700,
    })
    FilePond.create(
      document.querySelector('form[action="/settings"] input[type="file"][name="icon"]'), {
        acceptedFileTypes: ['image/png', 'image/jpeg', 'image/gif'],
        imageResizeTargetWidth: 240,
        imageResizeTargetHeight: 240
    })
    $('.ui.feed .event')
      .find('.content img')
      .each(function () {
        $this = $(this)
        $this.attr('data-src', $this.attr('src'))
      })
      .end()
      .lightGallery({
        selector: '.content img',
        download: false
      })
    $('.ui.feed .event .label img').on('error', function() {
      $(this).replaceWith('<i class="user icon"></i>')
    })
  })
  $(document).on('submit', 'form:has(trix-editor)', function (e) {
    e.preventDefault()
  })
  $(document).on('click', 'form:has(trix-editor) input.ui.button', function (e) {
    e.preventDefault()
    const $this = $(this)
    const $form = $this.closest('form')
    $.ajax({
      type: $form.attr('method'),
      url: $this.attr('action'),
      data: $form.serialize(),
      dataType: 'html',
      success: function (_, _, xhr) {
        const location = xhr.getResponseHeader("Location")
        Turbolinks.visit(location || window.location)
      }
    })
  })
  $(window).on("trix-change", function (event) {
    if (event.target.hasContent != !!event.target.textContent) {
      (event.target.hasContent = !!event.target.textContent) ?
        $(event.target).closest('form').find('.buttons .button').removeClass('disabled') :
        $(event.target).closest('form').find('.buttons .button').addClass('disabled')
    }
  })
  $(window).on("trix-attachment-add", function(event) {
    event = event.originalEvent
    var attachment = event.attachment
    if (attachment.file) {
      var fd = new FormData()
      fd.append("Content-Type", attachment.file.type)
      fd.append("file", attachment.file)

      $.ajax({
        type: "POST",
        url: "/uploads",
        data: fd,
        processData: false,
        contentType: false,

        headers: {
          "X-CSRF-Token": Ktistec.csrf
        },

        xhr: function() {
          var xhr = new window.XMLHttpRequest()

          xhr.upload.addEventListener("progress", function(event) {
            if (event.lengthComputable) {
              var progress = event.loaded / event.total * 100
              attachment.setUploadProgress(progress)
            }
          }, false)

          xhr.addEventListener("progress", function(event) {
            if (event.lengthComputable) {
              var progress = event.loaded / event.total * 100
              attachment.setUploadProgress(progress)
            }
          }, false)

          xhr.addEventListener("load", function(event) {
            if (xhr.status == 201) {
              attachment.setAttributes({
                url: xhr.getResponseHeader("Location"),
                href: xhr.getResponseHeader("Location")
              })
            }
          })
          return xhr
        }
      })
    }
  })
  $(window).on("trix-attachment-remove", function(event) {
    event = event.originalEvent
    var attachment = event.attachment.attachment
    if (attachment.previewURL) {
      $.ajax({
        type: "DELETE",
        url: attachment.previewURL,
        headers: {
          "X-CSRF-Token": Ktistec.csrf
        }
      })
    }
  })
})(jQuery)
