import { describe, expect, it } from "vitest"

import { indexLabels, renderLabel } from "../lib/term_label"

describe("renderLabel", () => {
  it("styles the label by the term's type", () => {
    expect(renderLabel("#3dprinting").className).toEqual("ui label hashtag")
    expect(renderLabel("@bob@example.com").className).toEqual("ui label mention")
    expect(renderLabel("filament").className).toEqual("ui label keyword")
  })

  it("renders the term's text", () => {
    expect(renderLabel("filament").textContent).toEqual("filament")
  })

  it("renders whitespace as a dot per character", () => {
    expect(renderLabel("3d  print").querySelector(".space").textContent).toEqual("··")
  })

  it("styles a term whose whitespace is leading", () => {
    expect(renderLabel(" filament").classList).toContain("boundary-space")
  })

  it("styles a term whose whitespace is trailing", () => {
    expect(renderLabel("filament ").classList).toContain("boundary-space")
  })

  it("does not style a term whose whitespace is internal", () => {
    expect(renderLabel("3d print").classList).not.toContain("boundary-space")
  })

  it("includes a term's whitespace in its title", () => {
    expect(renderLabel(" filament").title).toEqual('" filament"')
  })

  it("carries the whole term in its title", () => {
    expect(renderLabel("https://example.com/actors/bob").title).toEqual("https://example.com/actors/bob")
  })

  it("puts the term's text in an element", () => {
    const label = renderLabel("3d print")

    expect(label.querySelector(".text").textContent).toEqual("3d·print")
  })

  it("leaves the delete icon outside the term's element", () => {
    const label = renderLabel("filament")

    expect(label.querySelector(".text .delete.icon")).toBeNull()
    expect(label.querySelector(".delete.icon")).not.toBeNull()
  })

  it("names the label after the term", () => {
    expect(renderLabel("filament").getAttribute("aria-label")).toEqual("filament")
  })

  it("quotes the name of a term with boundary space", () => {
    expect(renderLabel(" filament ").getAttribute("aria-label")).toEqual('" filament "')
  })
})

describe("indexLabels", () => {
  const labels = (count) => Array.from({ length: count }, (_, at) => renderLabel(`term ${at}`))

  it("numbers the labels", () => {
    const list = labels(3)
    indexLabels(list, 0)

    expect(list.map((label) => label.dataset.index)).toEqual(["0", "1", "2"])
  })

  it("numbers the delete icons", () => {
    const list = labels(3)
    indexLabels(list, 0)

    expect(list.map((label) => label.querySelector(".delete.icon").dataset.index)).toEqual([
      "0",
      "1",
      "2",
    ])
  })

  it("gives the list a single tab stop", () => {
    const list = labels(3)
    indexLabels(list, 1)

    expect(list.map((label) => label.tabIndex)).toEqual([-1, 0, -1])
  })

  it("leaves no tab stop", () => {
    const list = labels(2)
    indexLabels(list, 5)

    expect(list.map((label) => label.tabIndex)).toEqual([-1, -1])
  })
})
