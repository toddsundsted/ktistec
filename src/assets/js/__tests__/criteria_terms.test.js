import { describe, expect, it } from "vitest"

import {
  classifyTerm,
  hasBoundarySpace,
  moveTerm,
  segmentTerm,
  serialize,
  splitTerms,
} from "../lib/criteria_terms"

describe("splitTerms", () => {
  it("returns no terms for empty text", () => {
    expect(splitTerms("")).toEqual([])
  })

  it("splits on newlines", () => {
    expect(splitTerms("one\ntwo")).toEqual(["one", "two"])
  })

  it("normalizes CRLF line endings", () => {
    expect(splitTerms("one\r\ntwo")).toEqual(["one", "two"])
  })

  it("drops fully blank lines", () => {
    expect(splitTerms("one\n\n \t \ntwo")).toEqual(["one", "two"])
  })

  it("keeps leading and trailing whitespace verbatim", () => {
    expect(splitTerms(" filament \nresin")).toEqual([" filament ", "resin"])
  })

  it("keeps a term containing spaces as one term", () => {
    expect(splitTerms("3d print")).toEqual(["3d print"])
  })
})

describe("serialize", () => {
  it("returns empty text for no terms", () => {
    expect(serialize([])).toEqual("")
  })

  it("joins terms with newlines and no trailing newline", () => {
    expect(serialize(["one", "two"])).toEqual("one\ntwo")
  })

  it("round-trips terms with whitespace", () => {
    const terms = [" filament", "3d  print", "trailing "]

    expect(splitTerms(serialize(terms))).toEqual(terms)
  })
})

describe("moveTerm", () => {
  it("moves a term later", () => {
    expect(moveTerm(["a", "b", "c"], 0, 1)).toEqual(["b", "a", "c"])
  })

  it("moves a term earlier", () => {
    expect(moveTerm(["a", "b", "c"], 2, 0)).toEqual(["c", "a", "b"])
  })

  it("clamps a destination past the end", () => {
    expect(moveTerm(["a", "b", "c"], 0, 99)).toEqual(["b", "c", "a"])
  })

  it("clamps a destination before the start", () => {
    expect(moveTerm(["a", "b", "c"], 2, -99)).toEqual(["c", "a", "b"])
  })

  it("returns the terms unchanged for an out-of-range source", () => {
    expect(moveTerm(["a", "b"], 5, 0)).toEqual(["a", "b"])
  })

  it("does not mutate the terms it is given", () => {
    const terms = ["a", "b"]
    moveTerm(terms, 0, 1)

    expect(terms).toEqual(["a", "b"])
  })

  it("keeps duplicates", () => {
    expect(moveTerm(["a", "a", "b"], 2, 0)).toEqual(["b", "a", "a"])
  })
})

describe("classifyTerm", () => {
  it("classifies a leading hash as a hashtag", () => {
    expect(classifyTerm("#3dprinting")).toEqual("hashtag")
  })

  it("classifies a leading at-sign as a mention", () => {
    expect(classifyTerm("@bob@example.com")).toEqual("mention")
  })

  it("classifies an IRI as a mention", () => {
    expect(classifyTerm("https://example.com/actors/bob")).toEqual("mention")
  })

  it("classifies an IRI as a mention", () => {
    expect(classifyTerm("HTTPS://example.com/actors/bob")).toEqual("mention")
  })

  it("classifies anything else as a keyword", () => {
    expect(classifyTerm("3d print")).toEqual("keyword")
  })

  it("infers from the raw first character", () => {
    expect(classifyTerm("  #3dprinting")).toEqual("keyword")
  })
})

describe("segmentTerm", () => {
  it("returns no runs for an empty term", () => {
    expect(segmentTerm("")).toEqual([])
  })

  it("returns one run for a term without whitespace", () => {
    expect(segmentTerm("filament")).toEqual([{ space: false, text: "filament" }])
  })

  it("separates internal whitespace into its own run", () => {
    expect(segmentTerm("3d print")).toEqual([
      { space: false, text: "3d" },
      { space: true, text: " " },
      { space: false, text: "print" },
    ])
  })

  it("keeps a run of whitespace together", () => {
    expect(segmentTerm("3d  print")).toEqual([
      { space: false, text: "3d" },
      { space: true, text: "  " },
      { space: false, text: "print" },
    ])
  })

  it("returns leading and trailing whitespace as runs", () => {
    expect(segmentTerm(" filament ")).toEqual([
      { space: true, text: " " },
      { space: false, text: "filament" },
      { space: true, text: " " },
    ])
  })
})

describe("hasBoundarySpace", () => {
  it("is false for a term without whitespace", () => {
    expect(hasBoundarySpace("filament")).toBe(false)
  })

  it("is false for a term with only internal whitespace", () => {
    expect(hasBoundarySpace("3d print")).toBe(false)
  })

  it("is true for a term with leading whitespace", () => {
    expect(hasBoundarySpace(" filament")).toBe(true)
  })

  it("is true for a term with trailing whitespace", () => {
    expect(hasBoundarySpace("filament ")).toBe(true)
  })
})
