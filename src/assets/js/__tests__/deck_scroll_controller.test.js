import { describe, expect, it, beforeEach, afterEach } from "vitest"
import DeckScrollController from "../controllers/deck_scroll_controller"

describe("DeckScrollController", () => {
  let controllers
  let deck

  const panes = (element) => Array.from(element.querySelectorAll(".deck-pane"))

  const connect = (element) => {
    const controller = Object.create(DeckScrollController.prototype)
    Object.defineProperty(controller, "element", { value: element, writable: true })
    controller.connect()
    controllers.push(controller)
    return controller
  }

  // a clone, like Turbo's cached page, does not carry scroll offsets

  const restore = () => {
    document.dispatchEvent(new Event("turbo:before-cache"))
    const snapshot = deck.cloneNode(true)
    document.body.replaceChildren(snapshot)
    connect(snapshot)
    return snapshot
  }

  beforeEach(() => {
    controllers = []
    deck = document.createElement("div")
    deck.appendChild(document.createElement("turbo-stream-source"))
    for (let i = 0; i < 3; i++) {
      const pane = document.createElement("section")
      pane.className = "deck-pane"
      deck.appendChild(pane)
    }
    document.body.appendChild(deck)
  })

  afterEach(() => {
    for (const controller of controllers) {
      controller.disconnect()
    }
    document.body.innerHTML = ""
    document.documentElement.removeAttribute("data-turbo-preview")
  })

  describe("the restored snapshot", () => {
    it("restores the deck's horizontal scroll position", () => {
      connect(deck)
      deck.scrollLeft = 300

      expect(restore().scrollLeft).toEqual(300)
    })

    it("restores each pane's vertical scroll position", () => {
      connect(deck)
      panes(deck)[1].scrollTop = 2000
      panes(deck)[2].scrollTop = 500

      expect(panes(restore()).map((pane) => pane.scrollTop)).toEqual([0, 2000, 500])
    })

    it("removes the saved positions", () => {
      connect(deck)
      deck.scrollLeft = 300
      panes(deck)[0].scrollTop = 2000

      expect(restore().outerHTML).not.toContain("data-deck-scroll")
    })
  })

  describe("a preview", () => {
    it("is not restored", () => {
      connect(deck)
      panes(deck)[0].scrollTop = 2000
      document.documentElement.setAttribute("data-turbo-preview", "")

      expect(panes(restore())[0].scrollTop).toEqual(0)
    })
  })

  describe("disconnect", () => {
    it("stops saving", () => {
      connect(deck).disconnect()
      panes(deck)[0].scrollTop = 2000
      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(deck.outerHTML).not.toContain("data-deck-scroll")
    })
  })
})
