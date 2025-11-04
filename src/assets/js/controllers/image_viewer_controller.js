import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  /**
   * Disconnects the controller.
   *
   * Closes the image view modal.
   */
  disconnect() {
    this.closeModal()
  }

  /**
   * Handles clicks on the content element.
   *
   * Opens the viewer if a qualifying image was clicked.
   */
  handleClick(event) {
    const clickedElement = event.target

    if (clickedElement.tagName === "IMG" && this.isViewerImage(clickedElement)) {
      event.preventDefault()
      this.openViewer(clickedElement)
    }
  }

  /**
   * Determines if an image should be displayed in the viewer.
   *
   * An image qualifies if it's within this controller's content
   * element and either:
   *   - Inside a .extra.text element
   *   - Has the "attachment" class
   */
  isViewerImage(img) {
    const isInExtraText = img.closest(".extra.text") !== null
    const hasAttachmentClass = img.classList.contains("attachment")
    const isWithinContent = img.closest(".content") === this.element

    return isWithinContent && (isInExtraText || hasAttachmentClass)
  }

  /**
   * Opens the image viewer modal for the clicked image.
   *
   * Sets up the modal structure, prevents body scroll, and attaches
   * keyboard listeners.
   */
  openViewer(clickedImage) {
    this.previousActiveElement = document.activeElement

    this.collection = this.findCollection(clickedImage)
    this.currentIndex = this.collection.indexOf(clickedImage)

    const caption = this.extractCaption(clickedImage)
    this.createModal(clickedImage.src, clickedImage.alt || "", caption)

    this.showModal()

    if (this.collection && this.collection.length > 1) {
      this.updateNavigationButtons()
      this.updateAriaLabel()
      this.updatePagination()
    }

    this.updateZoomButtons()
    this.updateZoomLevelDisplay()
    this.updateCursor()

    // prevent body scroll on iOS Safari
    this.scrollPosition = window.pageYOffset || document.documentElement.scrollTop
    document.documentElement.classList.add('image-viewer-modal-open')
    document.body.classList.add('image-viewer-modal-open')
    document.body.style.top = `-${this.scrollPosition}px`
    document.body.style.position = 'fixed'
    document.body.style.width = '100%'

    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundHandleArrowKeys = this.handleArrowKeys.bind(this)
    this.boundHandleFullscreenChange = this.handleFullscreenChange.bind(this)

    document.addEventListener('keydown', this.boundHandleEscape)
    document.addEventListener('keydown', this.boundHandleArrowKeys)
    document.addEventListener('fullscreenchange', this.boundHandleFullscreenChange)

    this.initSwipeListeners()
    this.initPanListeners()
  }

  /**
   * Finds all viewer images in the same collection as the clicked image.
   *
   * Returns an array of image elements within the same .content element.
   */
  findCollection(clickedImage) {
    const contentElement = clickedImage.closest('.content')
    if (!contentElement) return [clickedImage]

    return Array.from(contentElement.querySelectorAll('img')).filter(img =>
      this.isViewerImage(img)
    )
  }

  /**
   * Creates and appends the modal DOM structure with proper ARIA
   * attributes.
   *
   * Sets up close handlers (button and backdrop) and implements focus
   * trapping for keyboard navigation accessibility.
   */
  createModal(imageSrc, imageAlt, caption) {
    this.removeModal()

    this.modal = document.createElement('div')
    this.modal.className = 'image-viewer-modal'
    this.modal.setAttribute('role', 'dialog')
    this.modal.setAttribute('aria-modal', 'true')
    this.modal.setAttribute('aria-label', 'Image viewer')
    this.modal.setAttribute('aria-hidden', 'true')
    this.modal.setAttribute('tabindex', '-1')

    // initialize caption height CSS variable
    this.modal.style.setProperty('--caption-height', '0px')

    const backdrop = document.createElement('div')
    backdrop.className = 'image-viewer-modal__backdrop'

    const container = document.createElement('div')
    container.className = 'image-viewer-modal__container'

    const controls = document.createElement('div')
    controls.className = 'image-viewer-modal__controls'

    // left group

    const leftGroup = document.createElement('div')
    leftGroup.className = 'image-viewer-modal__controls-left'

    const rightGroup = document.createElement('div')
    rightGroup.className = 'image-viewer-modal__controls-right'

    if (this.collection && this.collection.length > 1) {
      const pagination = document.createElement('div')
      pagination.className = 'image-viewer-modal__pagination'
      pagination.setAttribute('aria-live', 'polite')
      pagination.setAttribute('aria-atomic', 'true')
      leftGroup.appendChild(pagination)

      this.paginationElement = pagination
    }

    const zoomLevelDisplay = document.createElement('div')
    zoomLevelDisplay.className = 'image-viewer-modal__zoom-level'
    zoomLevelDisplay.setAttribute('aria-live', 'polite')
    zoomLevelDisplay.style.display = 'none'
    leftGroup.appendChild(zoomLevelDisplay)

    this.zoomLevelDisplay = zoomLevelDisplay

    // right group

    if (this.collection && this.collection.length > 1) {

      const prevButton = document.createElement('button')
      prevButton.className = 'image-viewer-modal__prev'
      prevButton.type = 'button'
      prevButton.setAttribute('aria-label', 'Previous image')
      prevButton.setAttribute('tabindex', '0')

      const prevIcon = document.createElement('i')
      prevIcon.className = 'angle left icon'
      prevIcon.setAttribute('aria-hidden', 'true')
      prevButton.appendChild(prevIcon)

      prevButton.addEventListener('click', () => this.navigatePrev())
      rightGroup.appendChild(prevButton)

      const nextButton = document.createElement('button')
      nextButton.className = 'image-viewer-modal__next'
      nextButton.type = 'button'
      nextButton.setAttribute('aria-label', 'Next image')
      nextButton.setAttribute('tabindex', '0')

      const nextIcon = document.createElement('i')
      nextIcon.className = 'angle right icon'
      nextIcon.setAttribute('aria-hidden', 'true')
      nextButton.appendChild(nextIcon)

      nextButton.addEventListener('click', () => this.navigateNext())
      rightGroup.appendChild(nextButton)

      this.prevButton = prevButton
      this.nextButton = nextButton
    }

    const zoomOutButton = document.createElement('button')
    zoomOutButton.className = 'image-viewer-modal__zoom-out'
    zoomOutButton.type = 'button'
    zoomOutButton.setAttribute('aria-label', 'Zoom out')
    zoomOutButton.setAttribute('tabindex', '0')

    const zoomOutIcon = document.createElement('i')
    zoomOutIcon.className = 'zoom out icon'
    zoomOutIcon.setAttribute('aria-hidden', 'true')
    zoomOutButton.appendChild(zoomOutIcon)

    zoomOutButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.zoomOut()
    })
    rightGroup.appendChild(zoomOutButton)

    this.zoomOutButton = zoomOutButton

    const zoomInButton = document.createElement('button')
    zoomInButton.className = 'image-viewer-modal__zoom-in'
    zoomInButton.type = 'button'
    zoomInButton.setAttribute('aria-label', 'Zoom in')
    zoomInButton.setAttribute('tabindex', '0')

    const zoomInIcon = document.createElement('i')
    zoomInIcon.className = 'zoom in icon'
    zoomInIcon.setAttribute('aria-hidden', 'true')
    zoomInButton.appendChild(zoomInIcon)

    zoomInButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.zoomIn()
    })
    rightGroup.appendChild(zoomInButton)

    this.zoomInButton = zoomInButton

    const resetZoomButton = document.createElement('button')
    resetZoomButton.className = 'image-viewer-modal__reset-zoom'
    resetZoomButton.type = 'button'
    resetZoomButton.setAttribute('aria-label', 'Reset zoom')
    resetZoomButton.setAttribute('tabindex', '0')
    resetZoomButton.setAttribute('disabled', 'true')

    const resetZoomIcon = document.createElement('i')
    resetZoomIcon.className = 'compress icon'
    resetZoomIcon.setAttribute('aria-hidden', 'true')
    resetZoomButton.appendChild(resetZoomIcon)

    resetZoomButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.resetZoom()
    })
    rightGroup.appendChild(resetZoomButton)

    this.resetZoomButton = resetZoomButton

    const fullscreenButton = document.createElement('button')
    fullscreenButton.className = 'image-viewer-modal__fullscreen'
    fullscreenButton.type = 'button'
    fullscreenButton.setAttribute('aria-label', 'Enter fullscreen')
    fullscreenButton.setAttribute('tabindex', '0')

    const fullscreenIcon = document.createElement('i')
    fullscreenIcon.className = 'expand icon'
    fullscreenIcon.setAttribute('aria-hidden', 'true')
    fullscreenButton.appendChild(fullscreenIcon)

    fullscreenButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.toggleFullscreen()
    })
    rightGroup.appendChild(fullscreenButton)

    this.fullscreenButton = fullscreenButton
    this.fullscreenIcon = fullscreenIcon

    const closeButton = document.createElement('button')
    closeButton.className = 'image-viewer-modal__close'
    closeButton.type = 'button'
    closeButton.setAttribute('aria-label', 'Close image viewer')
    closeButton.setAttribute('tabindex', '0')

    const closeIcon = document.createElement('i')
    closeIcon.className = 'times icon'
    closeIcon.setAttribute('aria-hidden', 'true')
    closeButton.appendChild(closeIcon)

    rightGroup.appendChild(closeButton)

    controls.appendChild(leftGroup)
    controls.appendChild(rightGroup)

    const content = document.createElement('div')
    content.className = 'image-viewer-modal__content'

    const imageWrapper = document.createElement('div')
    imageWrapper.className = 'image-viewer-modal__image-wrapper'

    const image = document.createElement('img')
    image.className = 'image-viewer-modal__image'
    image.src = imageSrc
    image.alt = imageAlt
    image.loading = 'eager'
    image.setAttribute('tabindex', '-1')

    image.addEventListener('load', () => {
      this.naturalImageWidth = image.naturalWidth
      this.naturalImageHeight = image.naturalHeight
      this.updateZoomLimits()
      this.constrainPan()
    })

    imageWrapper.appendChild(image)
    content.appendChild(imageWrapper)

    this.currentImageElement = image
    this.imageWrapper = imageWrapper
    this.fullscreenElement = content
    this.zoomLevel = 1.0
    this.naturalImageWidth = 0
    this.naturalImageHeight = 0
    this.maxZoomLevel = 4.0
    this.panX = 0
    this.panY = 0
    this.isPanning = false
    this.panStartX = 0
    this.panStartY = 0
    this.panStartPanX = 0
    this.panStartPanY = 0

    container.appendChild(content)

    this.modal.appendChild(backdrop)
    this.modal.appendChild(controls)
    this.modal.appendChild(container)

    if (caption) {
      const captionDiv = document.createElement('div')
      captionDiv.className = 'image-viewer-modal__caption'
      captionDiv.setAttribute('role', 'region')
      captionDiv.setAttribute('aria-live', 'polite')
      captionDiv.innerHTML = caption
      this.modal.appendChild(captionDiv)
      this.captionElement = captionDiv
    }

    document.body.appendChild(this.modal)

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.updateCaptionHeight()
        if (this.captionElement) {
          this.captionResizeObserver = new ResizeObserver(() => {
            this.updateCaptionHeight()
          })
          this.captionResizeObserver.observe(this.captionElement)
        }
      })
    })

    closeButton.addEventListener('click', () => this.closeModal())
    backdrop.addEventListener('click', () => this.closeModal())

    // focus trap: prevent tabbing outside the modal
    this.modal.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        const focusableElements = this.modal.querySelectorAll('button, [tabindex]:not([tabindex="-1"])')
        const firstElement = focusableElements[0]
        const lastElement = focusableElements[focusableElements.length - 1]
        if (e.shiftKey && document.activeElement === firstElement) {
          e.preventDefault()
          lastElement.focus()
        } else if (!e.shiftKey && document.activeElement === lastElement) {
          e.preventDefault()
          firstElement.focus()
        }
      }
    })
  }

  /**
   * Makes the modal visible by updating ARIA attributes and setting
   * focus on the close button.
   */
  showModal() {
    requestAnimationFrame(() => {
      this.modal.setAttribute('aria-hidden', 'false')
      const closeBtn = this.modal.querySelector('.image-viewer-modal__close')
      if (closeBtn) {
        closeBtn.focus()
      } else {
        this.modal.focus()
      }
    })
  }

  /**
   * Closes the image view modal.
   *
   * Hides and removes the modal, restores body scroll, removes event
   * listeners, and returns focus to the element that triggered the
   * viewer.
   */
  closeModal() {
    if (!this.modal) return

    if (this.modal.contains(document.activeElement)) {
      document.activeElement.blur()
    }

    this.modal.setAttribute('aria-hidden', 'true')

    if (this.boundHandleEscape) {
      document.removeEventListener('keydown', this.boundHandleEscape)
      this.boundHandleEscape = null
    }

    if (this.boundHandleArrowKeys) {
      document.removeEventListener('keydown', this.boundHandleArrowKeys)
      this.boundHandleArrowKeys = null
    }

    if (this.boundHandleFullscreenChange) {
      document.removeEventListener('fullscreenchange', this.boundHandleFullscreenChange)
      this.boundHandleFullscreenChange = null
    }

    if (this.isFullscreen()) {
      this.exitFullscreen()
    }

    // restore scroll position on iOS Safari
    document.documentElement.classList.remove('image-viewer-modal-open')
    document.body.classList.remove('image-viewer-modal-open')
    document.body.style.top = ''
    document.body.style.position = ''
    document.body.style.width = ''
    if (this.scrollPosition !== undefined) {
      window.scrollTo(0, this.scrollPosition)
      this.scrollPosition = undefined
    }

    // use transitionend event to remove modal after animation
    // completes. use fallback timeout in case transitionend doesn't
    // fire.

    let transitionCompleted = false

    const removeAfterTransition = () => {
      if (transitionCompleted) return
      transitionCompleted = true

      this.removeModal()
      if (this.previousActiveElement) {
        this.previousActiveElement.focus()
        this.previousActiveElement = null
      }
    }

    const transitionHandler = (e) => {
      if (e.target !== this.modal) return
      this.modal.removeEventListener('transitionend', transitionHandler)
      if (this.modalTransitionTimeout) {
        clearTimeout(this.modalTransitionTimeout)
        this.modalTransitionTimeout = null
      }
      removeAfterTransition()
    }

    this.modal.addEventListener('transitionend', transitionHandler)

    this.modalTransitionTimeout = setTimeout(() => {
      this.modal.removeEventListener('transitionend', transitionHandler)
      this.modalTransitionTimeout = null
      removeAfterTransition()
    }, 200)
  }

  /**
   * Removes the modal from the DOM.
   */
  removeModal() {
    if (this.modal && this.modal.parentNode) {
      // clean up any pending transition timeout
      if (this.modalTransitionTimeout) {
        clearTimeout(this.modalTransitionTimeout)
        this.modalTransitionTimeout = null
      }

      const content = this.modal.querySelector('.image-viewer-modal__content')
      if (content && this.boundTouchStart && this.boundTouchEnd) {
        content.removeEventListener('touchstart', this.boundTouchStart)
        content.removeEventListener('touchend', this.boundTouchEnd)
      }

      if (content && this.boundPanMouseDown) {
        content.removeEventListener('mousedown', this.boundPanMouseDown)
      }

      if (this.boundPanMouseMove) {
        document.removeEventListener('mousemove', this.boundPanMouseMove)
      }

      if (this.boundPanMouseUp) {
        document.removeEventListener('mouseup', this.boundPanMouseUp)
      }

      if (content && this.boundPanTouchStartPan) {
        content.removeEventListener('touchstart', this.boundPanTouchStartPan)
      }

      if (this.boundPanTouchMovePan) {
        document.removeEventListener('touchmove', this.boundPanTouchMovePan)
      }

      if (this.boundPanTouchEndPan) {
        document.removeEventListener('touchend', this.boundPanTouchEndPan)
      }

      if (this.captionResizeObserver) {
        this.captionResizeObserver.disconnect()
        this.captionResizeObserver = null
      }

      this.modal.parentNode.removeChild(this.modal)
      this.modal = null
      this.collection = null
      this.currentImageElement = null
      this.currentIndex = null
      this.prevButton = null
      this.nextButton = null
      this.paginationElement = null
      this.fullscreenButton = null
      this.fullscreenIcon = null
      this.fullscreenElement = null
      this.zoomInButton = null
      this.zoomOutButton = null
      this.resetZoomButton = null
      this.zoomLevelDisplay = null
      this.imageWrapper = null
      this.captionElement = null
      this.zoomLevel = 1.0
      this.naturalImageWidth = 0
      this.naturalImageHeight = 0
      this.maxZoomLevel = 4.0
      this.panX = 0
      this.panY = 0
      this.isPanning = false
    }
  }

  /**
   * Updates the CSS custom property for caption height.
   */
  updateCaptionHeight() {
    if (!this.modal) return

    const caption = this.captionElement || this.modal.querySelector('.image-viewer-modal__caption')
    if (caption && caption.style.display !== 'none') {
      const height = caption.offsetHeight
      this.modal.style.setProperty('--caption-height', `${height}px`)
    } else {
      this.modal.style.setProperty('--caption-height', '0px')
    }
  }

  /**
   * Handles Escape keypress to close the modal.
   */
  handleEscape(event) {
    if (event.key === 'Escape' || event.keyCode === 27) {
      if (this.isFullscreen()) {
        this.exitFullscreen()
      } else {
        this.closeModal()
      }
    }
  }

  /**
   * Checks if the viewer is in fullscreen mode.
   */
  isFullscreen() {
    return !!(document.fullscreenElement ||
              document.webkitFullscreenElement ||
              document.mozFullScreenElement ||
              document.msFullscreenElement)
  }

  /**
   * Toggles fullscreen mode.
   */
  toggleFullscreen() {
    if (this.isFullscreen()) {
      this.exitFullscreen()
    } else {
      this.enterFullscreen()
    }
  }

  /**
   * Enters fullscreen mode.
   */
  enterFullscreen() {
    const element = this.fullscreenElement || this.currentImageElement
    if (!element) return

    const requestFullscreen = element.requestFullscreen ||
                              element.webkitRequestFullscreen ||
                              element.mozRequestFullScreen ||
                              element.msRequestFullscreen

    if (requestFullscreen) {
      const promise = requestFullscreen.call(element)
      if (promise && promise instanceof Promise) {
        promise.catch((err) => {
          console.warn('Fullscreen request failed:', err)
        })
      }
    }
  }

  /**
   * Exits fullscreen mode.
   */
  exitFullscreen() {
    if (document.exitFullscreen) {
      document.exitFullscreen()
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen()
    } else if (document.mozCancelFullScreen) {
      document.mozCancelFullScreen()
    } else if (document.msExitFullscreen) {
      document.msExitFullscreen()
    }
  }

  /**
   * Handles fullscreen state changes.
   */
  handleFullscreenChange() {
    if (!this.fullscreenButton || !this.fullscreenIcon) return

    if (this.isFullscreen()) {
      this.fullscreenButton.setAttribute('aria-label', 'Exit fullscreen')
      this.fullscreenIcon.className = 'compress icon'
    } else {
      this.fullscreenButton.setAttribute('aria-label', 'Enter fullscreen')
      this.fullscreenIcon.className = 'expand icon'
    }
  }

  /**
   * Updates zoom limits based on natural image size.
   */
  updateZoomLimits() {
    if (!this.currentImageElement || !this.naturalImageWidth || !this.naturalImageHeight) {
      return
    }

    const rect = this.currentImageElement.getBoundingClientRect()
    const displayedWidth = rect.width
    const displayedHeight = rect.height

    if (displayedWidth > 0 && displayedHeight > 0) {
      const widthRatio = this.naturalImageWidth / displayedWidth
      const heightRatio = this.naturalImageHeight / displayedHeight
      this.maxZoomLevel = Math.max(widthRatio, heightRatio, 4.0)
    }
  }

  /**
   * Zooms in by 0.25x increments.
   */
  zoomIn() {
    const newZoom = Math.min(this.zoomLevel + 0.25, this.maxZoomLevel)
    this.setZoom(newZoom)
  }

  /**
   * Zooms out by 0.25x increments.
   */
  zoomOut() {
    const newZoom = Math.max(this.zoomLevel - 0.25, 1.0)
    this.setZoom(newZoom)
  }

  /**
   * Sets the zoom level.
   */
  setZoom(level) {
    const wasZoomed = this.zoomLevel > 1.0
    this.zoomLevel = Math.max(1.0, Math.min(level, this.maxZoomLevel))

    if (this.zoomLevel === 1.0 && wasZoomed) {
      this.resetPan()
    } else {
      this.constrainPan()
    }

    this.applyTransform()
    this.updateZoomButtons()
    this.updateZoomLevelDisplay()
    this.updateCursor()
  }

  /**
   * Resets zoom to 1.0x.
   */
  resetZoom() {
    this.setZoom(1.0)
    this.resetPan()
  }

  /**
   * Applies transform (scale + translate) to the image wrapper.
   */
  applyTransform() {
    if (!this.imageWrapper) return

    if (this.isPanning) {
      this.imageWrapper.classList.add('no-transition')
    } else {
      this.imageWrapper.classList.remove('no-transition')
    }

    this.imageWrapper.style.transform = `scale(${this.zoomLevel}) translate(${this.panX}px, ${this.panY}px)`
    this.imageWrapper.style.transformOrigin = 'center center'
  }

  /**
   * Resets pan position.
   */
  resetPan() {
    this.panX = 0
    this.panY = 0
    this.applyTransform()
  }

  /**
   * Constrains pan to image bounds.
   */
  constrainPan() {
    if (!this.currentImageElement || this.zoomLevel <= 1.0) {
      this.panX = 0
      this.panY = 0
      this.applyTransform()
      return
    }

    const content = this.modal.querySelector('.image-viewer-modal__content')
    if (!content) return

    const contentRect = content.getBoundingClientRect()
    const viewportWidth = contentRect.width
    const viewportHeight = contentRect.height

    const imageRect = this.currentImageElement.getBoundingClientRect()
    const scaledWidth = imageRect.width
    const scaledHeight = imageRect.height

    if (scaledWidth <= 0 || scaledHeight <= 0) return

    const maxPanX = scaledWidth > viewportWidth ? (scaledWidth - viewportWidth) / 2 : 0
    const maxPanY = scaledHeight > viewportHeight ? (scaledHeight - viewportHeight) / 2 : 0

    this.panX = Math.max(-maxPanX, Math.min(maxPanX, this.panX))
    this.panY = Math.max(-maxPanY, Math.min(maxPanY, this.panY))

    this.applyTransform()
  }

  /**
   * Initializes pan event listeners.
   */
  initPanListeners() {
    const content = this.modal.querySelector('.image-viewer-modal__content')
    if (!content) return

    this.boundPanMouseDown = this.handlePanMouseDown.bind(this)
    this.boundPanMouseMove = this.handlePanMouseMove.bind(this)
    this.boundPanMouseUp = this.handlePanMouseUp.bind(this)

    content.addEventListener('mousedown', this.boundPanMouseDown)

    this.boundPanTouchStartPan = this.handlePanTouchStart.bind(this)
    this.boundPanTouchMovePan = this.handlePanTouchMove.bind(this)
    this.boundPanTouchEndPan = this.handlePanTouchEnd.bind(this)

    content.addEventListener('touchstart', this.boundPanTouchStartPan, { passive: false })
  }

  /**
   * Handles mouse down for panning.
   */
  handlePanMouseDown(event) {
    if (this.zoomLevel <= 1.0) return
    if (event.target !== this.currentImageElement && !this.imageWrapper.contains(event.target)) return
    if (event.target.closest('button')) return

    event.preventDefault()
    this.isPanning = true
    this.panStartX = event.clientX
    this.panStartY = event.clientY
    this.panStartPanX = this.panX
    this.panStartPanY = this.panY

    document.addEventListener('mousemove', this.boundPanMouseMove)
    document.addEventListener('mouseup', this.boundPanMouseUp)

    this.updateCursor()
  }

  /**
   * Handles mouse move for panning.
   */
  handlePanMouseMove(event) {
    if (!this.isPanning) return

    event.preventDefault()
    const deltaX = event.clientX - this.panStartX
    const deltaY = event.clientY - this.panStartY

    this.panX = this.panStartPanX + (deltaX / this.zoomLevel)
    this.panY = this.panStartPanY + (deltaY / this.zoomLevel)

    this.constrainPan()
  }

  /**
   * Handles mouse up for panning.
   */
  handlePanMouseUp() {
    if (!this.isPanning) return

    this.isPanning = false
    document.removeEventListener('mousemove', this.boundPanMouseMove)
    document.removeEventListener('mouseup', this.boundPanMouseUp)

    this.updateCursor()
  }

  /**
   * Handles touch start for panning.
   */
  handlePanTouchStart(event) {
    if (this.zoomLevel <= 1.0) return
    if (event.touches.length !== 1) return
    if (event.target !== this.currentImageElement && !this.imageWrapper.contains(event.target)) return

    event.preventDefault()
    this.isPanning = true
    const touch = event.touches[0]
    this.panStartX = touch.clientX
    this.panStartY = touch.clientY
    this.panStartPanX = this.panX
    this.panStartPanY = this.panY

    document.addEventListener('touchmove', this.boundPanTouchMovePan, { passive: false })
    document.addEventListener('touchend', this.boundPanTouchEndPan)
  }

  /**
   * Handles touch move for panning.
   */
  handlePanTouchMove(event) {
    if (!this.isPanning || event.touches.length !== 1) return

    event.preventDefault()
    const touch = event.touches[0]
    const deltaX = touch.clientX - this.panStartX
    const deltaY = touch.clientY - this.panStartY

    this.panX = this.panStartPanX + (deltaX / this.zoomLevel)
    this.panY = this.panStartPanY + (deltaY / this.zoomLevel)

    this.constrainPan()
  }

  /**
   * Handles touch end for panning.
   */
  handlePanTouchEnd() {
    if (!this.isPanning) return

    this.isPanning = false
    document.removeEventListener('touchmove', this.boundPanTouchMovePan)
    document.removeEventListener('touchend', this.boundPanTouchEndPan)
  }

  /**
   * Updates cursor style based on zoom and pan state.
   */
  updateCursor() {
    const content = this.modal.querySelector('.image-viewer-modal__content')
    if (!content) return

    if (this.isPanning) {
      content.style.cursor = 'grabbing'
    } else if (this.zoomLevel > 1.0) {
      content.style.cursor = 'grab'
    } else {
      content.style.cursor = 'default'
    }
  }

  /**
   * Updates zoom button states.
   */
  updateZoomButtons() {
    if (!this.zoomInButton || !this.zoomOutButton || !this.resetZoomButton) return

    const isZoomed = this.zoomLevel > 1.0
    const canZoomIn = this.zoomLevel < this.maxZoomLevel
    const canZoomOut = this.zoomLevel > 1.0

    if (canZoomIn) {
      this.zoomInButton.removeAttribute('disabled')
      this.zoomInButton.setAttribute('aria-label', 'Zoom in')
    } else {
      this.zoomInButton.setAttribute('disabled', 'true')
      this.zoomInButton.setAttribute('aria-label', 'Zoom in (at maximum)')
    }

    if (canZoomOut) {
      this.zoomOutButton.removeAttribute('disabled')
      this.zoomOutButton.setAttribute('aria-label', 'Zoom out')
    } else {
      this.zoomOutButton.setAttribute('disabled', 'true')
      this.zoomOutButton.setAttribute('aria-label', 'Zoom out (at minimum)')
    }

    if (isZoomed) {
      this.resetZoomButton.removeAttribute('disabled')
      this.resetZoomButton.setAttribute('tabindex', '0')
      this.resetZoomButton.setAttribute('aria-label', 'Reset zoom')
    } else {
      this.resetZoomButton.setAttribute('disabled', 'true')
      this.resetZoomButton.setAttribute('tabindex', '-1')
      this.resetZoomButton.setAttribute('aria-label', 'Reset zoom (at minimum)')
    }
  }

  /**
   * Updates zoom level display.
   */
  updateZoomLevelDisplay() {
    if (!this.zoomLevelDisplay) return

    if (this.zoomLevel > 1.0) {
      const percentage = Math.round(this.zoomLevel * 100)
      this.zoomLevelDisplay.textContent = `${percentage}%`
      this.zoomLevelDisplay.style.display = 'block'
    } else {
      this.zoomLevelDisplay.style.display = 'none'
    }
  }

  /**
   * Handles arrow keypress for image navigation.
   */
  handleArrowKeys(event) {
    if (!this.modal || !this.collection || this.collection.length <= 1) {
      return
    }

    if (this.modal.getAttribute('aria-hidden') === 'true') {
      return
    }

    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault()
      if (event.key === 'ArrowLeft') {
        this.navigatePrev()
      } else {
        this.navigateNext()
      }
    }
  }

  /**
   * Extracts caption text from an image.
   *
   * Prefers figcaption over alt text. Returns null if no caption is
   * found.
   *
   * Note: figcaption HTML is trusted and used directly because all
   * content (local and remote) is sanitized server-side via
   * Ktistec::Util.sanitize, which whitelists only safe formatting
   * elements (strong, em, sup, sub, del, ins, s) and strips all
   * attributes and dangerous elements. Alt text is escaped since it
   * contains user-provided content that hasn't been sanitized.
   */
  extractCaption(clickedImage) {
    const figure = clickedImage.closest('figure')
    if (figure) {
      const figcaption = figure.querySelector('figcaption')
      if (figcaption && figcaption.textContent.trim()) {
        return figcaption.innerHTML.trim()
      }
    }

    if (clickedImage.alt && clickedImage.alt.trim()) {
      return this.escapeHtml(clickedImage.alt.trim())
    }

    return null
  }

  /**
   * Escapes HTML.
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Navigates to the previous image in the collection.
   */
  navigatePrev() {
    if (this.currentIndex > 0) {
      this.navigateTo(this.currentIndex - 1)
    }
  }

  /**
   * Navigates to the next image in the collection.
   */
  navigateNext() {
    if (this.currentIndex < this.collection.length - 1) {
      this.navigateTo(this.currentIndex + 1)
    }
  }

  /**
   * Navigates to a specific image by index.
   *
   * Updates the displayed image, caption, and navigation button states.
   */
  navigateTo(index) {
    if (!this.collection || index < 0 || index >= this.collection.length) {
      return
    }

    this.currentIndex = index
    const image = this.collection[index]
    const caption = this.extractCaption(image)

    this.updateImage(image.src, image.alt || "", caption)
    this.updateNavigationButtons()
    this.updateAriaLabel()
    this.updatePagination()
    this.resetZoom()
    this.resetPan()
  }

  /**
   * Updates the displayed image and caption.
   */
  updateImage(imageSrc, imageAlt, caption) {
    const image = this.modal.querySelector('.image-viewer-modal__image')
    let captionDiv = this.captionElement || this.modal.querySelector('.image-viewer-modal__caption')

    if (image) {
      image.style.opacity = '0'
      const transitionHandler = () => {
        image.removeEventListener('transitionend', transitionHandler)
        image.src = imageSrc
        image.alt = imageAlt

        image.addEventListener('load', () => {
          this.naturalImageWidth = image.naturalWidth
          this.naturalImageHeight = image.naturalHeight
          this.updateZoomLimits()
          this.constrainPan()
        }, { once: true })

        requestAnimationFrame(() => {
          image.style.opacity = '1'
          image.focus()
          this.currentImageElement = image
        })
      }
      image.addEventListener('transitionend', transitionHandler, { once: true })
    }

    if (caption) {
      if (captionDiv) {
        captionDiv.innerHTML = caption
        captionDiv.style.display = 'block'
      } else {
        captionDiv = document.createElement('div')
        captionDiv.className = 'image-viewer-modal__caption'
        captionDiv.setAttribute('role', 'region')
        captionDiv.setAttribute('aria-live', 'polite')
        captionDiv.innerHTML = caption
        const container = this.modal.querySelector('.image-viewer-modal__container')
        if (container) {
          container.insertAdjacentElement('afterend', captionDiv)
        } else {
          this.modal.appendChild(captionDiv)
        }
        this.captionElement = captionDiv
        if (this.captionResizeObserver) {
          this.captionResizeObserver.disconnect()
        }
        this.captionResizeObserver = new ResizeObserver(() => {
          this.updateCaptionHeight()
        })
        this.captionResizeObserver.observe(captionDiv)
      }

      requestAnimationFrame(() => {
        this.updateCaptionHeight()
      })
    } else {
      if (captionDiv) {
        captionDiv.remove()
        this.captionElement = null

        if (this.captionResizeObserver) {
          this.captionResizeObserver.disconnect()
          this.captionResizeObserver = null
        }
      }

      this.updateCaptionHeight()
    }
  }

  /**
   * Updates navigation button visibility based on current position.
   */
  updateNavigationButtons() {
    if (!this.prevButton || !this.nextButton) return

    if (this.currentIndex === 0) {
      this.prevButton.style.display = 'none'
    } else {
      this.prevButton.style.display = 'flex'
    }

    if (this.currentIndex === this.collection.length - 1) {
      this.nextButton.style.display = 'none'
    } else {
      this.nextButton.style.display = 'flex'
    }
  }

  /**
   * Updates the modal ARIA label with current position.
   */
  updateAriaLabel() {
    if (this.collection && this.collection.length > 1) {
      const position = `${this.currentIndex + 1} of ${this.collection.length}`
      this.modal.setAttribute('aria-label', `Image viewer (${position})`)
    }
  }

  /**
   * Updates the pagination display with current position.
   */
  updatePagination() {
    if (this.paginationElement && this.collection && this.collection.length > 1) {
      this.paginationElement.textContent = `${this.currentIndex + 1}/${this.collection.length}`
    }
  }

  /**
   * Initializes touch event listeners for swipe detection.
   */
  initSwipeListeners() {
    const content = this.modal.querySelector('.image-viewer-modal__content')
    if (!content) return

    // skip swipe detection when zoomed (pan handles it)

    this.boundTouchStart = (e) => {
      if (this.zoomLevel > 1.0) return
      if (e.touches.length !== 1) return

      const touch = e.touches[0]
      this.touchStartX = touch.clientX
      this.touchStartY = touch.clientY
    }

    this.boundTouchEnd = (e) => {
      if (this.zoomLevel > 1.0) return
      if (e.changedTouches.length !== 1) return

      const touch = e.changedTouches[0]
      this.touchEndX = touch.clientX
      this.touchEndY = touch.clientY
      this.handleSwipe()
    }

    content.addEventListener('touchstart', this.boundTouchStart, { passive: true })
    content.addEventListener('touchend', this.boundTouchEnd, { passive: true })
  }

  /**
   * Handles swipe gesture detection and navigation.
   */
  handleSwipe() {
    if (this.touchStartX === null || this.touchStartX === undefined ||
        this.touchEndX === null || this.touchEndX === undefined) {
      return
    }

    const deltaX = this.touchEndX - this.touchStartX
    const deltaY = this.touchEndY - this.touchStartY

    // swipe left/right
    const minSwipeDistance = 50
    const maxVerticalDistance = 30
    // swipe up
    const minVerticalSwipeDistance = 100
    const maxHorizontalDistance = 50

    // check for vertical swipe (flick up to close)
    if (deltaY < -minVerticalSwipeDistance && Math.abs(deltaX) < maxHorizontalDistance) {
      this.closeModal()
      this.touchStartX = null
      this.touchStartY = null
      this.touchEndX = null
      this.touchEndY = null
      return
    }

    // check for horizontal swipe (navigate left/right)
    if (Math.abs(deltaX) > minSwipeDistance && Math.abs(deltaY) < maxVerticalDistance) {
      if (deltaX > 0) {
        this.navigatePrev()
      } else {
        this.navigateNext()
      }
    }

    this.touchStartX = null
    this.touchStartY = null
    this.touchEndX = null
    this.touchEndY = null
  }
}
