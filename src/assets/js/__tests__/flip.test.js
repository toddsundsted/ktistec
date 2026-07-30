import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"

import { flip } from "../lib/flip"

describe("flip", () => {
  const element = (left, top) => {
    const node = document.createElement("span")
    place(node, left, top)
    return node
  }

  const place = (node, left, top) => {
    node.getBoundingClientRect = () => ({ left: left, top: top })
  }

  // the next frame is what clears the inversion, so a test that wants
  // to see the inverted state has to keep the frame from arriving
  const holdFrame = () => vi.stubGlobal("requestAnimationFrame", () => {})

  beforeEach(() => {
    vi.stubGlobal("requestAnimationFrame", (callback) => callback())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("runs the mutation", () => {
    const mutate = vi.fn()
    flip([], mutate)

    expect(mutate).toHaveBeenCalled()
  })

  it("leaves an element the mutation did not move alone", () => {
    const node = element(0, 0)
    holdFrame()
    flip([node], () => {})

    expect(node.style.transform).toEqual("")
  })

  it("starts a moved element from where it was", () => {
    const node = element(0, 0)
    holdFrame()
    flip([node], () => place(node, 30, 40))

    expect(node.style.transform).toEqual("translate(-30px, -40px)")
  })

  it("suspends the transition while it puts the element back", () => {
    const node = element(0, 0)
    holdFrame()
    flip([node], () => place(node, 30, 40))

    expect(node.style.transition).toEqual("none")
  })

  it("lets the element travel to where it belongs on the next frame", () => {
    const node = element(0, 0)
    flip([node], () => place(node, 30, 40))

    expect(node.style.transform).toEqual("")
    expect(node.style.transition).toEqual("")
  })

  // a rearrangement usually starts while the last one is still
  // animating, and an element part-way through that animation is not
  // at its layout position. measuring where it appears and settling it
  // before the mutation is what carries the motion through.
  it("settles an in-flight element before the mutation measures it", () => {
    const node = element(0, 0)
    node.style.transform = "translate(10px, 10px)"
    let transform = null

    flip([node], () => {
      transform = node.style.transform
      place(node, 30, 40)
    })

    expect(transform).toEqual("")
  })
})
