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
    this.navigationMode = false
    this.currentNavigationId = null
    this.currentDisplaySource = 'cached'

    this.navigationHistory = []
    this.currentHistoryIndex = -1
  }

  disconnect() {
    if (this.boundHandleKeydown) {
      document.removeEventListener("keydown", this.boundHandleKeydown)
      this.boundHandleKeydown = null
    }

    this.closeOverlay()

    this.cachedData = null
    this.remoteData = null
    this.navigationMode = false
    this.currentNavigationId = null
    this.currentDisplaySource = 'cached'
    this.navigationHistory = []
    this.currentHistoryIndex = -1
  }

  handleKeydown(event) {
    // check for Ctrl+Shift+X
    if (event.ctrlKey && event.shiftKey && event.key === 'X') {
      event.preventDefault()
      this.toggleOverlay()
    }

    // check Escape to close overlay
    if (event.key === 'Escape' && this.hasOverlay()) {
      event.preventDefault()
      this.closeOverlay()
    }

    // check Alt+Left/Alt-Right for X-ray navigation
    if (this.hasOverlay() && event.altKey && !event.ctrlKey && !event.shiftKey) {
      if (event.key === 'ArrowLeft') {
        event.preventDefault()
        this.navigateBack()
      } else if (event.key === 'ArrowRight') {
        event.preventDefault()
        this.navigateForward()
      }
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

      const currentId = this.extractIdFromData(this.cachedData) || window.location.pathname
      this.addToNavigationHistory(currentId, this.cachedData, null)

      this.displayJSON(this.cachedData, 'cached')
      this.updateRemoteButtonVisibility()
      this.updateNavigationButtons()
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
          <button id="xray-back-btn" class="xray-modal__back" type="button" aria-label="Navigate back" disabled>
            <i class="chevron left icon" aria-hidden="true"></i>
          </button>
          <button id="xray-forward-btn" class="xray-modal__forward" type="button" aria-label="Navigate forward" disabled>
            <i class="chevron right icon" aria-hidden="true"></i>
          </button>
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
    overlay.querySelector('#xray-back-btn').addEventListener('click', () => this.navigateBack())
    overlay.querySelector('#xray-forward-btn').addEventListener('click', () => this.navigateForward())
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
    this.navigationMode = false
    this.currentNavigationId = null
    this.currentDisplaySource = 'cached'
    this.navigationHistory = []
    this.currentHistoryIndex = -1
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
    this.currentDisplaySource = source
    const jsonEl = document.getElementById('xray-json')
    if (jsonEl) {
      jsonEl.innerHTML = this.highlightJSONObject(data)

      const clickableIds = jsonEl.querySelectorAll('.xray-json-clickable')
      clickableIds.forEach(element => {
        element.style.cursor = 'pointer'
        element.addEventListener('click', (e) => {
          e.preventDefault()
          e.stopPropagation()
          const id = element.getAttribute('data-id')
          if (id) {
            this.navigateToId(id)
          }
        })
      })
    }
    this.updateButtonStates(source)
  }

  updateButtonStates(active) {
    const cachedBtn = document.getElementById('xray-cached-btn')
    const remoteBtn = document.getElementById('xray-remote-btn')

    if (cachedBtn && remoteBtn) {
      if (this.navigationMode) {
        cachedBtn.style.display = 'none'
        remoteBtn.style.display = 'none'
      } else {
        cachedBtn.style.display = 'flex'
        cachedBtn.classList.toggle('active', active === 'cached')
        remoteBtn.classList.toggle('active', active === 'remote')
      }
    }

    this.updateTitle(active)
  }

  updateRemoteButtonVisibility() {
    const remoteBtn = document.getElementById('xray-remote-btn')
    if (remoteBtn && this.cachedData) {
      // show remote button only if we have an ActivityPub ID from a different server
      const activityPubId = this.cachedData['id'] || this.cachedData['@id']
      const hasRemoteId = activityPubId && !this.isLocalId(activityPubId)

      remoteBtn.style.display = hasRemoteId ? 'flex' : 'none'

      this.updateTitle()
    }
  }

  updateTitle(activeSource = null) {
    const title = document.getElementById('xray-title')
    if (!title) return

    const baseTitle = 'X-Ray Mode'

    if (activeSource === 'navigation') {
      const displayId = this.currentNavigationId || 'Unknown'
      title.textContent = `${baseTitle} - ${displayId}`
    } else if (activeSource === 'remote') {
      const activityPubId = this.remoteData && (this.remoteData['id'] || this.remoteData['@id'])
      const displayId = activityPubId ? `- ${activityPubId}` : ''
      title.textContent = `${baseTitle} (Remote) ${displayId}`
    } else if (activeSource === 'cached') {
      const activityPubId = this.cachedData && (this.cachedData['id'] || this.cachedData['@id'])
      let suffix
      if (!activityPubId) {
        suffix = ' (Local - Anonymous)'
      } else if (this.isLocalId(activityPubId)) {
        suffix = ` (Local) - ${activityPubId}`
      } else {
        suffix = ` (Cached) - ${activityPubId}`
      }
      title.textContent = baseTitle + suffix
    }
  }

  highlightJSONObject(obj, indent = 0, parentKey = null) {
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
      if (this.isClickableId(obj, parentKey)) {
        return `<span class="xray-json-string xray-json-clickable" data-id="${this.escapeHtml(obj)}">"${escaped}"</span>`
      }
      return `<span class="xray-json-string">"${escaped}"</span>`
    }
    if (Array.isArray(obj)) {
      if (obj.length === 0) {
        return '[]'
      }
      const items = obj.map(item =>
        nextIndentStr + this.highlightJSONObject(item, indent + 1, parentKey)
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
        const value = this.highlightJSONObject(obj[key], indent + 1, key)
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

  /**
   * Fetch data from local server.
   *
   */
  async fetchLocal(url = null) {
    const fetchUrl = url || (window.location.pathname + window.location.search)
    const fetchOptions = {
      headers: {'Accept': 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"'},
      credentials: 'same-origin'
    }
    try {
      const response = await fetch(fetchUrl, fetchOptions)
      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`HTTP ${response.status} ${response.statusText}: ${errorText}`)
      }
      const contentType = response.headers.get('Content-Type') || ''
      if (!contentType.includes('json')) {
        throw new Error('Response does not provide JSON representation')
      }
      return response.json()
    } catch (error) {
      throw new Error(`Local fetch failed: ${error.message}`)
    }
  }

  /**
   * Fetch data via proxy endpoint.
   *
   */
  async fetchViaProxy(id) {
    if (!id) {
      throw new Error('ID is required for proxy fetch')
    }
    const fetchOptions = {
      method: 'POST',
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      credentials: 'same-origin',
      body: JSON.stringify({ id })
    }
    try {
      const response = await fetch('/proxy', fetchOptions)
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        const errorMessage = `HTTP ${response.status} ${response.statusText}: ${errorData.msg}`
        throw new Error(errorMessage)
      }
      return response.json()
    } catch (error) {
      throw new Error(`Proxy fetch failed: ${error.message}`)
    }
  }

  async fetchCurrentPage() {
    return this.fetchLocal()
  }

  async fetchRemote() {
    const cachedData = this.cachedData
    if (!cachedData) {
      throw new Error('No cached data available')
    }
    const objectIri = cachedData['id'] || cachedData['@id']
    if (!objectIri) {
      throw new Error('No ActivityPub ID found')
    }
    return this.fetchViaProxy(objectIri)
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
      if (!this.navigationMode) {
        this.updateTitle('cached')
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
      if (!this.navigationMode) {
        this.updateTitle('remote')
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

  isIdProperty(propertyName) {
    const coreIdProps = [
      'id', '@id'
    ]
    const objectIdProps = [
      'actor', 'object', 'target', 'origin', 'context',
      'attributedTo', 'inReplyTo', 'partOf', 'describes'
    ]
    const collectionProps = [
      'first', 'last', 'next', 'prev', 'current', 'self',
      'following', 'followers', 'liked', 'shares',
      'outbox', 'inbox', 'orderedItems', 'items'
    ]
    const arrayIdProps = [
      'to', 'cc', 'bto', 'bcc', 'tag'
    ]
    return coreIdProps.includes(propertyName) ||
           objectIdProps.includes(propertyName) ||
           collectionProps.includes(propertyName) ||
           arrayIdProps.includes(propertyName)
  }

  isValidActivityPubId(value) {
    if (typeof value !== 'string' || !value.trim()) {
      return false
    }
    try {
      const url = new URL(value.trim())
      return url.protocol === 'http:' || url.protocol === 'https:'
    } catch {
      return false
    }
  }

  isClickableId(value, propertyName) {
    return this.isValidActivityPubId(value) && this.isIdProperty(propertyName)
  }

  async navigateToId(id) {
    try {
      this.navigationMode = true
      this.currentNavigationId = id

      this.showLoading()

      let data
      if (this.isLocalId(id)) {
        try {
          data = await this.fetchLocal(id)
        } catch (error) {
          data = await this.fetchViaProxy(id)
        }
      } else {
        data = await this.fetchViaProxy(id)
      }

      this.addToNavigationHistory(id, data, null)

      this.displayJSON(data, 'navigation')
      this.updateTitle('navigation')

    } catch (error) {
      console.error('Navigation error:', error)
      alert(`Error navigating to ${id}: ${error.message}`)
    }
  }

  addToNavigationHistory(id, cachedData, remoteData) {
    if (this.currentHistoryIndex < this.navigationHistory.length - 1) {
      this.navigationHistory = this.navigationHistory.slice(0, this.currentHistoryIndex + 1)
    }

    this.navigationHistory.push({
      id: id,
      cachedData: cachedData,
      remoteData: remoteData,
      timestamp: Date.now()
    })

    this.currentHistoryIndex = this.navigationHistory.length - 1
    this.updateNavigationButtons()
    this.updateTitle('navigation')
  }

  navigateBack() {
    if (this.currentHistoryIndex > 0) {
      this.currentHistoryIndex--
      const entry = this.navigationHistory[this.currentHistoryIndex]
      this.displayJSON(entry.cachedData, 'navigation')
      this.currentNavigationId = entry.id
      this.updateNavigationButtons()
      this.updateTitle('navigation')
    }
  }

  navigateForward() {
    if (this.currentHistoryIndex < this.navigationHistory.length - 1) {
      this.currentHistoryIndex++
      const entry = this.navigationHistory[this.currentHistoryIndex]
      this.displayJSON(entry.cachedData, 'navigation')
      this.currentNavigationId = entry.id
      this.updateNavigationButtons()
      this.updateTitle('navigation')
    }
  }

  updateNavigationButtons() {
    const backBtn = document.getElementById('xray-back-btn')
    const forwardBtn = document.getElementById('xray-forward-btn')

    if (backBtn) {
      backBtn.disabled = this.currentHistoryIndex <= 0
      if (backBtn.disabled) {
        backBtn.blur()
      }
    }
    if (forwardBtn) {
      forwardBtn.disabled = this.currentHistoryIndex >= this.navigationHistory.length - 1
      if (forwardBtn.disabled) {
        forwardBtn.blur()
      }
    }
  }

  extractIdFromData(data) {
    if (!data) return null
    return data['id'] || data['@id'] || null
  }
}
