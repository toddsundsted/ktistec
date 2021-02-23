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

  /**
   * Toolbar.
   */
  Trix.config.toolbar.getDefaultHTML = function() {
    let {lang} = Trix.config
    return `
    <div class="trix-toolbar-container">
      <div class="ui compact mini icon menu">
        <button class="item" data-trix-attribute="bold" data-trix-key="b" title="${lang.bold}"><i class="bold icon"></i></button>
        <button class="item" data-trix-attribute="italic" data-trix-key="i" title="${lang.italic}"><i class="italic icon"></i></button>
        <button class="item" data-trix-attribute="strike" title="${lang.strike}"><i class="strikethrough icon"></i></button>
        <button class="item" data-trix-attribute="code" title="${lang.code}"><i class="code icon"></i></button>
        <button class="item" data-trix-attribute="sup" title="Superscript"><i class="superscript icon"></i></button>
        <button class="item" data-trix-attribute="sub" title="Subscript"><i class="subscript icon"></i></button>
        <button class="item" data-trix-attribute="href" data-trix-action="link" data-trix-key="k"title="${lang.link}"><i class="linkify icon"></i></button>
      </div>
      <div class="ui compact mini icon menu">
          <button class="item" data-trix-attribute="heading1" title="${lang.heading1}"><i class="heading icon"></i></button>
          <button class="item" data-trix-attribute="quote" title="${lang.quote}"><i class="quote right icon"></i></button>
          <button class="item" data-trix-attribute="pre" title="${lang.code}"><i class="code icon"></i></button>
          <button class="item" data-trix-attribute="bullet" title="${lang.bullets}"><i class="list ul icon"></i></button>
          <button class="item" data-trix-attribute="number" title="${lang.numbers}"><i class="list ol icon"></i></button>
          <button class="item" data-trix-action="decreaseNestingLevel" title="${lang.outdent}"><i class="outdent icon"></i></button>
          <button class="item" data-trix-action="increaseNestingLevel" title="${lang.indent}"><i class="indent icon"></i></button>
      </div>
      <div class="ui compact mini icon menu">
        <button class="item" data-trix-action="attachFiles" title="${lang.attachFiles}"><i class="paperclip icon"></i></button>
      </div>
      <div class="ui compact mini icon menu">
        <button class="item trix-button--icon-undo" data-trix-action="undo" data-trix-key="z" title="${lang.undo}"><i class="undo icon"></i></button>
        <button class="item trix-button--icon-redo" data-trix-action="redo" data-trix-key="shift+z" title="${lang.redo}"><i class="redo icon"></i></button>
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
   * Typeahead.
   */
  $(document).on('turbolinks:load', function () {
    $('trix-editor').each(function() {
      const editor = this.editor
      const previous_keydown = editor.composition.delegate.inputController.events.keydown
      editor.composition.delegate.inputController.events.keydown = function(keydown) {
        if (keydown.keyCode == 8 /* backspace */ && editor.suggestion) {
          editor.backspacing = true
        }
        else if (keydown.keyCode == 27 /* escape */ && editor.suggestion) {
          editor.insertString('')
          editor.selectionManager.delegate.requestedRender = true
          editor.backspacing = true
          keydown.preventDefault()
        }
        else if (keydown.keyCode == 9 /* tab */ && editor.suggestion) {
          let [begin, end] = editor.getSelectedRange()
          editor.setSelectedRange([end, end])
          editor.suggestion = undefined
          keydown.preventDefault()
        }
        previous_keydown.call(this, keydown)
      }
    })
  })
  $(window).on('trix-change', function (event) {
    const editor =  event.target.editor
    const document = editor.getDocument().toString()
    const position = editor.getPosition()
    if (editor.edit_lock)
      return
    if (editor.backspacing) {
      editor.backspacing = false
      return
    }
    for (var i = 1; i < 64; i++) {
      let ch1 = document[position - i]
      let ch2 = document[position - i - 1]
      if ((ch1 == "#" || ch1 == "@") && (ch2 == " " || ch2 == "\n" || !ch2)) {
        break
      }
      if (ch1 == " " || ch1 == "\n" || !ch1) {
        i--
        break
      }
    }
    for (var j = 0; j < 64; j++) {
      let ch = document[position + j]
      if (ch == " " || ch == "\n" || !ch) {
        break
      }
    }
    let prefix = document.substring(position - i, position)
    let suffix = document.substring(position, position + j)
    if (!suffix && prefix.length > 2 && (prefix[0] == "#" || prefix[0] == "@")) {
      editor.edit_lock = true
      if (!editor.suggestion || !editor.suggestion.startsWith(prefix)) {
        let url
        switch (prefix[0]) {
        case '#':
          url = `/tags?hashtag=${prefix.slice(1)}`
          break
        case '@':
          url = `/tags?mention=${prefix.slice(1)}`
          break
        }
        if (url) {
          $.get(url).then(function(suggestion) {
            editor.suggestion = `${prefix[0]}${suggestion}`
          })
        }
      }
      if (editor.suggestion && editor.suggestion.toLowerCase().startsWith(prefix.toLowerCase())) {
        let suggestion = editor.suggestion.substring(prefix.length)
        editor.insertString(suggestion)
        editor.setSelectedRange([position, position + suggestion.length])
      }
      editor.edit_lock = false
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
