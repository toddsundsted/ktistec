import { Controller } from "@hotwired/stimulus"

/**
 * X-ray Mode for viewing cached and remote ActivityPub JSON-LD
 * representations.
 *
 */
export default class extends Controller {
  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)

    document.addEventListener("keydown", this.boundHandleKeydown)

    this.cachedData = null
    this.remoteData = null
  }

  disconnect() {
    if (this.boundHandleKeydown) {
      document.removeEventListener("keydown", this.boundHandleKeydown)
      this.boundHandleKeydown = null
    }

    this.closeOverlay()

    this.cachedData = null
    this.remoteData = null
  }

  handleKeydown(event) {
    // check for Ctrl+Shift+X
    if (event.ctrlKey && event.shiftKey && event.key === 'X') {
      event.preventDefault()
      this.toggleOverlay()
    }
    if (event.key === 'Escape' && this.hasOverlay()) {
      event.preventDefault()
      this.closeOverlay()
    }
  }

  toggleOverlay() {
    if (this.hasOverlay()) {
      this.closeOverlay()
    } else {
      this.openOverlay()
    }
  }

  async openOverlay() {
    if (this.hasOverlay()) {
      return
    }
    try {
      this.createOverlay()
      this.showLoading()
      this.cachedData = await this.fetchCurrentPage()
      this.displayJSON(this.cachedData, 'cached')
      this.updateRemoteButtonVisibility()
      this.showOverlay()
    } catch (error) {
      console.error('X-ray mode error:', error)
      alert(`X-ray mode error: ${error.message}`)
      this.closeOverlay()
    }
  }

  createOverlay() {
    this.scrollPosition = window.pageYOffset || document.documentElement.scrollTop
    document.body.style.setProperty('--xray-scroll-offset', `-${this.scrollPosition}px`)
    document.documentElement.classList.add('xray-modal-open')
    document.body.classList.add('xray-modal-open')

    const overlay = document.createElement('div')
    overlay.id = 'xray-overlay'
    overlay.className = 'xray-modal'
    overlay.setAttribute('role', 'dialog')
    overlay.setAttribute('aria-modal', 'true')
    overlay.setAttribute('aria-label', 'X-Ray Mode')
    overlay.setAttribute('aria-hidden', 'true')
    overlay.setAttribute('tabindex', '-1')

    overlay.innerHTML = `
      <div class="xray-modal__backdrop"></div>
      <div class="xray-modal__controls">
        <div class="xray-modal__controls-left">
          <div class="xray-modal__title" id="xray-title">X-Ray Mode</div>
        </div>
        <div class="xray-modal__controls-right">
          <button id="xray-cached-btn" class="xray-modal__cached active" type="button" aria-label="Show locally cached version">
            <i class="database icon" aria-hidden="true"></i>
          </button>
          <button id="xray-remote-btn" class="xray-modal__remote" type="button" aria-label="Show remote version">
            <i class="cloud icon" aria-hidden="true"></i>
          </button>
          <button id="xray-close-btn" class="xray-modal__close" type="button" aria-label="Close X-Ray Mode">
            <i class="times icon" aria-hidden="true"></i>
          </button>
        </div>
      </div>
      <div class="xray-modal__container">
        <div class="xray-modal__content">
          <pre id="xray-json" class="xray-modal__json"></pre>
        </div>
      </div>
    `

    overlay.querySelector('#xray-close-btn').addEventListener('click', () => this.closeOverlay())
    overlay.querySelector('#xray-cached-btn').addEventListener('click', () => this.showCached())
    overlay.querySelector('#xray-remote-btn').addEventListener('click', () => this.showRemote())
    overlay.querySelector('.xray-modal__backdrop').addEventListener('click', () => this.closeOverlay())

    // focus trap
    overlay.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        const focusableElements = overlay.querySelectorAll('button, [tabindex]:not([tabindex="-1"])')
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

    document.body.appendChild(overlay)
  }

  closeOverlay() {
    const overlay = document.getElementById('xray-overlay')
    if (overlay) {
      overlay.setAttribute('aria-hidden', 'true')

      let transitionCompleted = false

      const removeAfterTransition = () => {
        if (transitionCompleted) return
        transitionCompleted = true

        if (overlay.parentNode) {
          overlay.parentNode.removeChild(overlay)
        }

        document.documentElement.classList.remove('xray-modal-open')
        document.body.classList.remove('xray-modal-open')
        document.body.style.removeProperty('--xray-scroll-offset')
        if (this.scrollPosition !== undefined) {
          window.scrollTo(0, this.scrollPosition)
          this.scrollPosition = undefined
        }
      }

      const transitionHandler = (e) => {
        if (e.target !== overlay) return
        overlay.removeEventListener('transitionend', transitionHandler)
        if (this.overlayTransitionTimeout) {
          clearTimeout(this.overlayTransitionTimeout)
          this.overlayTransitionTimeout = null
        }
        removeAfterTransition()
      }

      overlay.addEventListener('transitionend', transitionHandler)

      this.overlayTransitionTimeout = setTimeout(() => {
        overlay.removeEventListener('transitionend', transitionHandler)
        this.overlayTransitionTimeout = null
        removeAfterTransition()
      }, 200)
    } else {
      document.documentElement.classList.remove('xray-modal-open')
      document.body.classList.remove('xray-modal-open')
      document.body.style.removeProperty('--xray-scroll-offset')
    }

    this.cachedData = null
    this.remoteData = null
  }

  hasOverlay() {
    return !!document.getElementById('xray-overlay')
  }

  showLoading() {
    const jsonEl = document.getElementById('xray-json')
    if (jsonEl) {
      jsonEl.textContent = 'Loading...'
    }
  }

  displayJSON(data, source) {
    const jsonEl = document.getElementById('xray-json')
    if (jsonEl) {
      jsonEl.innerHTML = this.highlightJSONObject(data)
    }
    this.updateButtonStates(source)
  }

  updateButtonStates(active) {
    const cachedBtn = document.getElementById('xray-cached-btn')
    const remoteBtn = document.getElementById('xray-remote-btn')

    if (cachedBtn && remoteBtn) {
      cachedBtn.classList.toggle('active', active === 'cached')
      remoteBtn.classList.toggle('active', active === 'remote')
    }

    this.updateTitle(active)
  }

  updateRemoteButtonVisibility() {
    const remoteBtn = document.getElementById('xray-remote-btn')
    if (remoteBtn && this.cachedData) {
      // show remote button only if we have an ActivityPub ID from a different server
      const activityPubId = this.cachedData.id || this.cachedData['@id']
      const hasRemoteId = activityPubId && !this.isLocalId(activityPubId)

      remoteBtn.style.display = hasRemoteId ? 'flex' : 'none'

      this.updateTitle()
    }
  }

  updateTitle(activeSource = null) {
    const title = document.getElementById('xray-title')
    if (!title) return

    const baseTitle = 'X-Ray Mode'

    if (activeSource === 'remote') {
      title.textContent = baseTitle + ' (Remote)'
    } else if (activeSource === 'cached') {
      const activityPubId = this.cachedData && (this.cachedData.id || this.cachedData['@id'])
      let suffix
      if (!activityPubId) {
        suffix = ' (Local - Anonymous)'
      } else if (this.isLocalId(activityPubId)) {
        suffix = ' (Local)'
      } else {
        suffix = ' (Cached)'
      }
      title.textContent = baseTitle + suffix
    }
  }

  highlightJSONObject(obj, indent = 0) {
    const indentStr = '  '.repeat(indent)
    const nextIndentStr = '  '.repeat(indent + 1)

    if (obj === null) {
      return '<span class="xray-json-literal">null</span>'
    }
    if (typeof obj === 'boolean') {
      return `<span class="xray-json-literal">${obj}</span>`
    }
    if (typeof obj === 'number') {
      return `<span class="xray-json-number">${obj}</span>`
    }
    if (typeof obj === 'string') {
      const escaped = this.escapeHtml(obj)
      return `<span class="xray-json-string">"${escaped}"</span>`
    }
    if (Array.isArray(obj)) {
      if (obj.length === 0) {
        return '[]'
      }
      const items = obj.map(item =>
        nextIndentStr + this.highlightJSONObject(item, indent + 1)
      ).join(',\n')
      return `[\n${items}\n${indentStr}]`
    }
    if (typeof obj === 'object') {
      const keys = Object.keys(obj)
      if (keys.length === 0) {
        return '{}'
      }
      const items = keys.map(key => {
        const escapedKey = this.escapeHtml(key)
        const value = this.highlightJSONObject(obj[key], indent + 1)
        return `${nextIndentStr}<span class="xray-json-key">"${escapedKey}"</span>: ${value}`
      }).join(',\n')
      return `{\n${items}\n${indentStr}}`
    }

    // fallback
    return String(obj)
  }

  escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
  }

  async fetchCurrentPage() {
    const response = await fetch(window.location.pathname + window.location.search, {
      headers: {'Accept': 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"'},
      credentials: 'same-origin'
    })
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`HTTP ${response.status} ${response.statusText}: ${errorText}`)
    }
    const contentType = response.headers.get('Content-Type') || ''
    if (!contentType.includes('json')) {
      throw new Error('Page does not provide JSON representation')
    }
    return response.json()
  }

  async fetchRemote() {
    // get the ActivityPub ID from cached data
    const cached = this.cachedData || await this.fetchCurrentPage()
    const objectIri = cached.id || cached['@id']
    if (!objectIri) {
      throw new Error('No ActivityPub ID found for remote fetching')
    }

    const response = await fetch('/proxy', {
      method: 'POST',
      headers: {'Content-Type': 'application/json',},
      body: JSON.stringify({id: objectIri}),
      credentials: 'same-origin'
    })
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`HTTP ${response.status} ${response.statusText}: ${errorText}`)
    }
    const contentType = response.headers.get('Content-Type') || ''
    if (!contentType.includes('json')) {
      throw new Error('Page does not provide JSON representation')
    }
    return response.json()
  }

  async showCached() {
    try {
      if (this.cachedData) {
        this.displayJSON(this.cachedData, 'cached')
      } else {
        this.showLoading()
        this.cachedData = await this.fetchCurrentPage()
        this.displayJSON(this.cachedData, 'cached')
        this.updateRemoteButtonVisibility()
      }
    } catch (error) {
      alert(`Error fetching cached data: ${error.message}`)
    }
  }

  async showRemote() {
    try {
      if (this.remoteData) {
        this.displayJSON(this.remoteData, 'remote')
      } else {
        this.showLoading()
        this.remoteData = await this.fetchRemote()
        this.displayJSON(this.remoteData, 'remote')
        this.updateRemoteButtonVisibility()
      }
    } catch (error) {
      alert(`Error fetching remote data: ${error.message}`)
    }
  }

  showOverlay() {
    const overlay = document.getElementById('xray-overlay')
    if (overlay) {
      requestAnimationFrame(() => {
        overlay.setAttribute('aria-hidden', 'false')
        const closeBtn = overlay.querySelector('#xray-close-btn')
        if (closeBtn) {
          closeBtn.focus()
        } else {
          overlay.focus()
        }
      })
    }
  }

  isLocalId(id) {
    try {
      const url = new URL(id)
      return url.origin === window.location.origin
    } catch {
      return false
    }
  }
}
