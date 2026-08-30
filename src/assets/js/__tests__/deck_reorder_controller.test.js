import { describe, expect, it, beforeEach, vi } from "vitest"
import DeckReorderController from "../controllers/deck_reorder_controller"

// Builds a deck of `count` panes, each with a left and a right move
// form, and returns the deck plus a controller bound to `index`.
function build(count, index, overflow = false) {
  const deck = document.createElement("div")
  document.body.replaceChildren(deck)

  deck.appendChild(document.createElement("turbo-stream-source"))
  for (let i = 0; i < count; i++) {
    const pane = document.createElement("section")
    pane.className = "deck-pane"
    pane.dataset.name = `pane${i}`
    for (const direction of ["left", "right"]) {
      const form = document.createElement("form")
      form.action = `/panes/${i}/position`
      form.dataset.deckReorderDirection = direction
      // the server renders a position here for a submit without
      // javascript. the controller must not use it.
      const position = document.createElement("input")
      position.type = "hidden"
      position.name = "position"
      position.value = "server-rendered"
      form.appendChild(position)
      const button = document.createElement("button")
      button.disabled = direction === "left" ? i === 0 : i === count - 1 && !overflow
      button.classList.toggle("disabled", button.disabled)
      form.appendChild(button)
      pane.appendChild(form)
    }
    deck.appendChild(pane)
  }

  return { deck, controller: controllerFor(deck, index, overflow) }
}

function panes(deck) {
  return Array.from(deck.querySelectorAll(".deck-pane"))
}

function controllerFor(deck, index, overflow = false) {
  const controller = Object.create(DeckReorderController.prototype)
  Object.defineProperty(controller, "element", { value: panes(deck)[index], writable: true })
  Object.defineProperty(controller, "overflowValue", { value: overflow, writable: true })
  return controller
}

function move(controller, direction) {
  const form = controller.element.querySelector(`[data-deck-reorder-direction='${direction}']`)
  const event = { currentTarget: form, preventDefault: vi.fn() }
  controller.move(event)
  return event
}

function disabled(deck, direction) {
  return panes(deck).map((pane) => {
    const button = pane.querySelector(`[data-deck-reorder-direction='${direction}'] button`)
    expect(button.classList.contains("disabled")).toBe(button.disabled)
    return button.disabled
  })
}

function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0))
}

function names(deck) {
  return panes(deck).map((pane) => pane.dataset.name)
}

// The positions posted to the server, oldest first.
function sent() {
  return fetch.mock.calls.map((call) => call[1].body.get("position"))
}

describe("DeckReorderController", () => {
  beforeEach(() => {
    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ ok: true })))
  })

  it("moves the pane left", () => {
    const { deck, controller } = build(3, 1)
    move(controller, "left")
    expect(names(deck)).toEqual(["pane1", "pane0", "pane2"])
  })

  it("moves the pane right", () => {
    const { deck, controller } = build(3, 1)
    move(controller, "right")
    expect(names(deck)).toEqual(["pane0", "pane2", "pane1"])
  })

  it("preserves the moved pane's scroll position", () => {
    const { deck, controller } = build(3, 1)
    // a browser zeroes scrollTop when the node detaches, which is what
    // the controller compensates for. jsdom does not, so do it here.
    const insertBefore = deck.insertBefore.bind(deck)
    deck.insertBefore = (node, reference) => {
      const moved = insertBefore(node, reference)
      node.scrollTop = 0
      return moved
    }

    controller.element.scrollTop = 250
    move(controller, "left")
    expect(panes(deck)[0].scrollTop).toBe(250)
  })

  it("sends the pane's new position", async () => {
    const { deck, controller } = build(4, 3)
    move(controller, "left")
    await flush()
    expect(names(deck)).toEqual(["pane0", "pane1", "pane3", "pane2"])
    expect(sent()).toEqual(["2"])
  })

  it("does not start a write until the previous one lands", async () => {
    const settle = []
    vi.stubGlobal("fetch", vi.fn(() => new Promise((resolve) => settle.push(resolve))))

    const { deck } = build(4, 0)
    move(controllerFor(deck, 3), "left")
    move(controllerFor(deck, 2), "left")
    await flush()

    expect(fetch).toHaveBeenCalledTimes(1)

    settle[0]()
    await flush()

    expect(fetch).toHaveBeenCalledTimes(2)
  })

  it("disables the move that would now do nothing", () => {
    const { deck, controller } = build(3, 1)
    move(controller, "left")
    expect(disabled(deck, "left")).toEqual([true, false, false])
    expect(disabled(deck, "right")).toEqual([false, false, true])
  })

  it("does not navigate", () => {
    const { controller } = build(3, 1)
    expect(move(controller, "left").preventDefault).toHaveBeenCalled()
  })

  it("navigates when moving the leftmost pane left", () => {
    const { controller } = build(3, 0)
    expect(move(controller, "left").preventDefault).not.toHaveBeenCalled()
  })

  describe("given a deck with feeds it does not show", () => {
    it("navigates rather than moving the rightmost pane itself", () => {
      const { controller } = build(3, 2, true)
      expect(move(controller, "right").preventDefault).not.toHaveBeenCalled()
    })

    it("leaves the rightmost pane's move right enabled", () => {
      const { deck, controller } = build(3, 1, true)
      move(controller, "left")
      expect(disabled(deck, "right")).toEqual([false, false, false])
    })

    it("does not record the order itself", async () => {
      const { controller } = build(3, 2, true)
      move(controller, "right")
      await flush()
      expect(fetch).not.toHaveBeenCalled()
    })
  })
})
