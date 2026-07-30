import { beforeEach, describe, expect, it } from "vitest"

import { insertionIndex, measureSlots } from "../lib/drag_geometry"

describe("insertionIndex", () => {
  const row = [
    { left: 0, right: 100, top: 0, bottom: 20 },
    { left: 100, right: 200, top: 0, bottom: 20 },
    { left: 200, right: 300, top: 0, bottom: 20 },
  ]

  const rows = [
    { left: 0, right: 100, top: 0, bottom: 20 },
    { left: 0, right: 100, top: 20, bottom: 40 },
    { left: 0, right: 100, top: 40, bottom: 60 },
  ]

  it("names the first slot when there are no terms", () => {
    expect(insertionIndex([], 50, 10)).toEqual(0)
  })

  it("names the first slot ahead of the first term", () => {
    expect(insertionIndex(row, 10, 10)).toEqual(0)
  })

  it("counts a term the pointer past the middle of", () => {
    expect(insertionIndex(row, 60, 10)).toEqual(1)
  })

  it("does not count a term the pointer short of the middle of", () => {
    expect(insertionIndex(row, 40, 10)).toEqual(0)
  })

  it("names the slot after the last term", () => {
    expect(insertionIndex(row, 290, 10)).toEqual(3)
  })

  it("counts every term on a row above the pointer", () => {
    expect(insertionIndex(rows, 0, 50)).toEqual(2)
  })

  it("counts no term on a row below the pointer", () => {
    expect(insertionIndex(rows, 90, 10)).toEqual(1)
  })

  it("names a slot within a lower row", () => {
    expect(insertionIndex(rows, 90, 30)).toEqual(2)
  })
})

describe("measureSlots", () => {
  const label = (left, top = 0) => {
    const element = document.createElement("span")
    element.getBoundingClientRect = () => ({
      left: left, right: left + 100, top: top, bottom: top + 20,
    })
    return element
  }

  const scrollTo = (x, y) => {
    Object.defineProperty(window, "scrollX", { configurable: true, get: () => x })
    Object.defineProperty(window, "scrollY", { configurable: true, get: () => y })
  }

  beforeEach(() => scrollTo(0, 0))

  it("measures every label when nothing is dragged", () => {
    const labels = [label(0), label(100)]

    expect(measureSlots(labels, null).map((rect) => rect.left)).toEqual([0, 100])
  })

  it("leaves out the dragged label", () => {
    const labels = [label(0), label(100), label(200)]

    expect(measureSlots(labels, labels[1]).map((rect) => rect.left)).toEqual([0, 200])
  })

  describe("in page coordinates", () => {
    it("offsets a slot by the scroll position", () => {
      scrollTo(0, 300)

      expect(measureSlots([label(0, 50)], null)[0]).toEqual({
        left: 0, right: 100, top: 350, bottom: 370,
      })
    })

    it("offsets a slot horizontally", () => {
      scrollTo(40, 0)

      expect(measureSlots([label(0)], null)[0].left).toEqual(40)
    })
  })

  it("sets the dragged label's display to none while it measures", () => {
    const other = label(0)
    const dragged = label(100)
    const measure = other.getBoundingClientRect
    let display = null
    other.getBoundingClientRect = () => {
      display = dragged.style.display
      return measure()
    }

    measureSlots([other, dragged], dragged)

    expect(display).toEqual("none")
  })

  it("restores the dragged label's display", () => {
    const other = label(0)
    const dragged = label(100)

    measureSlots([other, dragged], dragged)

    expect(dragged.style.display).toEqual("")
  })
})
