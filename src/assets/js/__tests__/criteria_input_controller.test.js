import { describe, expect, it, beforeEach, afterEach } from "vitest"

import CriteriaInputController from "../controllers/criteria_input_controller"

describe("CriteriaInputController", () => {
  let controller

  beforeEach(() => {
    controller = Object.create(CriteriaInputController.prototype)
  })

  describe("splitTerms", () => {
    it("returns no terms for empty text", () => {
      expect(controller.splitTerms("")).toEqual([])
    })

    it("splits on newlines", () => {
      expect(controller.splitTerms("one\ntwo")).toEqual(["one", "two"])
    })

    it("normalizes CRLF line endings", () => {
      expect(controller.splitTerms("one\r\ntwo")).toEqual(["one", "two"])
    })

    it("drops fully blank lines", () => {
      expect(controller.splitTerms("one\n\n \t \ntwo")).toEqual(["one", "two"])
    })

    it("keeps leading and trailing whitespace verbatim", () => {
      expect(controller.splitTerms(" llm \nrust")).toEqual([" llm ", "rust"])
    })

    it("keeps a term containing spaces as one term", () => {
      expect(controller.splitTerms("3d print")).toEqual(["3d print"])
    })
  })

  describe("serialize", () => {
    it("returns empty text for no terms", () => {
      expect(controller.serialize([])).toEqual("")
    })

    it("joins terms with newlines and no trailing newline", () => {
      expect(controller.serialize(["one", "two"])).toEqual("one\ntwo")
    })

    it("round-trips terms with whitespace", () => {
      const terms = [" llm", "3d  print", "trailing "]

      expect(controller.splitTerms(controller.serialize(terms))).toEqual(terms)
    })
  })

  describe("classifyTerm", () => {
    it("classifies a leading hash as a hashtag", () => {
      expect(controller.classifyTerm("#fdm")).toEqual("hashtag")
    })

    it("classifies a leading at-sign as a mention", () => {
      expect(controller.classifyTerm("@user@example.com")).toEqual("mention")
    })

    it("classifies an IRI as a mention", () => {
      expect(controller.classifyTerm("https://example.com/actor")).toEqual("mention")
    })

    it("classifies an IRI as a mention", () => {
      expect(controller.classifyTerm("HTTPS://example.com/actor")).toEqual("mention")
    })

    it("classifies anything else as a keyword", () => {
      expect(controller.classifyTerm("3d print")).toEqual("keyword")
    })

    it("infers from the raw first character", () => {
      expect(controller.classifyTerm("  #fdm")).toEqual("keyword")
    })
  })

  describe("segmentTerm", () => {
    it("returns no runs for an empty term", () => {
      expect(controller.segmentTerm("")).toEqual([])
    })

    it("returns one run for a term without whitespace", () => {
      expect(controller.segmentTerm("llm")).toEqual([{ space: false, text: "llm" }])
    })

    it("separates internal whitespace into its own run", () => {
      expect(controller.segmentTerm("3d print")).toEqual([
        { space: false, text: "3d" },
        { space: true, text: " " },
        { space: false, text: "print" },
      ])
    })

    it("keeps a run of whitespace together", () => {
      expect(controller.segmentTerm("3d  print")).toEqual([
        { space: false, text: "3d" },
        { space: true, text: "  " },
        { space: false, text: "print" },
      ])
    })

    it("returns leading and trailing whitespace as runs", () => {
      expect(controller.segmentTerm(" llm ")).toEqual([
        { space: true, text: " " },
        { space: false, text: "llm" },
        { space: true, text: " " },
      ])
    })
  })

  describe("hasBoundarySpace", () => {
    it("is false for a term without whitespace", () => {
      expect(controller.hasBoundarySpace("llm")).toBe(false)
    })

    it("is false for a term with only internal whitespace", () => {
      expect(controller.hasBoundarySpace("3d print")).toBe(false)
    })

    it("is true for a term with leading whitespace", () => {
      expect(controller.hasBoundarySpace(" llm")).toBe(true)
    })

    it("is true for a term with trailing whitespace", () => {
      expect(controller.hasBoundarySpace("llm ")).toBe(true)
    })
  })

  describe("connected", () => {
    let element
    let textarea

    const labels = () =>
          Array.from(controller.field.querySelectorAll(".ui.label")).map((label) => label.textContent)

    const connect = (value) => {
      textarea.value = value
      controller = Object.create(CriteriaInputController.prototype)
      Object.defineProperty(controller, "textareaTarget", { value: textarea, writable: true })
      Object.defineProperty(controller, "placeholderValue", { value: "Add a term…", writable: true })
      controller.connect()
    }

    beforeEach(() => {
      element = document.createElement("div")
      textarea = document.createElement("textarea")
      element.appendChild(textarea)
      document.body.appendChild(element)
    })

    afterEach(() => {
      document.body.innerHTML = ""
    })

    it("hides the textarea", () => {
      connect("")

      expect(textarea.style.display).toEqual("none")
    })

    it("renders a label for each stored term", () => {
      connect("#fdm\nllm")

      expect(labels()).toEqual(["#fdm", "llm"])
    })

    it("classifies each label", () => {
      connect("#fdm\n@user@example.com\nllm")

      const classes = Array.from(controller.field.querySelectorAll(".ui.label")).map(
        (label) => label.className
      )

      expect(classes).toEqual(["ui label hashtag", "ui label mention", "ui label keyword"])
    })

    it("renders a term's whitespace as dots", () => {
      connect("3d print")

      expect(labels()).toEqual(["3d·print"])
    })

    it("renders whitespace as dots", () => {
      connect("3d print")

      expect(controller.field.querySelector(".space").textContent).toEqual("·")
    })

    it("renders a run of whitespace as a dot per character", () => {
      connect("3d  print")

      expect(controller.field.querySelector(".space").textContent).toEqual("··")
    })

    it("marks a label whose whitespace is leading", () => {
      connect(" llm")

      expect(controller.field.querySelector(".ui.label").classList).toContain("boundary-space")
    })

    it("marks a label whose whitespace is trailing", () => {
      connect("llm ")

      expect(controller.field.querySelector(".ui.label").classList).toContain("boundary-space")
    })

    it("does not mark a label whose whitespace is internal", () => {
      connect("3d print")

      expect(controller.field.querySelector(".ui.label").classList).not.toContain("boundary-space")
    })

    it("restores the textarea on disconnect", () => {
      connect("llm")
      controller.disconnect()

      expect(textarea.style.display).toEqual("")
      expect(element.querySelector(".ui.labels")).toBeNull()
    })

    describe("committing", () => {
      it("appends the entry as a term", () => {
        connect("")
        controller.entry.value = "llm"
        controller._commit()

        expect(labels()).toEqual(["llm"])
      })

      it("writes the term back to the textarea", () => {
        connect("")
        controller.entry.value = "llm"
        controller._commit()

        expect(textarea.value).toEqual("llm")
      })

      it("clears the entry", () => {
        connect("")
        controller.entry.value = "llm"
        controller._commit()

        expect(controller.entry.value).toEqual("")
      })

      it("keeps whitespace in the entry verbatim", () => {
        connect("")
        controller.entry.value = " llm"
        controller._commit()

        expect(textarea.value).toEqual(" llm")
      })

      it("ignores an entry that is only whitespace", () => {
        connect("")
        controller.entry.value = "   "
        controller._commit()

        expect(labels()).toEqual([])
      })

      it("commits multi-line text as multiple terms", () => {
        connect("")
        controller._commit("one\ntwo")

        expect(labels()).toEqual(["one", "two"])
      })

      it("commits a multi-line paste as multiple terms", () => {
        connect("")
        controller._paste({
          clipboardData: { getData: () => "one\ntwo" },
          preventDefault: () => {},
        })

        expect(labels()).toEqual(["one", "two"])
      })

      it("leaves a single-line paste", () => {
        connect("")
        controller._paste({
          clipboardData: { getData: () => "one" },
          preventDefault: () => {},
        })

        expect(labels()).toEqual([])
      })
    })

    describe("the restored snapshot", () => {
      // Turbo caches the page before Stimulus disconnects. Without a
      // teardown the snapshot holds the injected field and the hidden
      // textarea, and a restoration visit connects another one beside
      // it.
      const restore = (source) => {
        const snapshot = source.cloneNode(true)
        document.body.appendChild(snapshot)
        const restored = Object.create(CriteriaInputController.prototype)
        Object.defineProperty(restored, "textareaTarget", {
          value: snapshot.querySelector("textarea"),
          writable: true,
        })
        Object.defineProperty(restored, "placeholderValue", { value: "Add a term…", writable: true })
        restored.connect()
        return snapshot
      }

      it("leaves an empty textarea in the cache", () => {
        connect("llm")
        document.dispatchEvent(new Event("turbo:before-cache"))

        expect(element.querySelector(".ui.labels")).toBeNull()
        expect(textarea.style.display).toEqual("")
      })

      it("connects once against a cached snapshot", () => {
        connect("llm")
        document.dispatchEvent(new Event("turbo:before-cache"))

        expect(restore(element).querySelectorAll(".ui.labels").length).toEqual(1)
      })

      it("connects once even without teardown", () => {
        connect("llm")

        expect(restore(element).querySelectorAll(".ui.labels").length).toEqual(1)
      })
    })

    describe("the keyboard", () => {
      const press = (target, key) => {
        const event = new KeyboardEvent("keydown", { key: key, cancelable: true, bubbles: true })
        target.dispatchEvent(event)
        return event
      }

      it("commits the entry on Enter", () => {
        connect("")
        controller.entry.value = "llm"
        press(controller.entry, "Enter")

        expect(labels()).toEqual(["llm"])
      })

      it("prevents Enter from submitting the form", () => {
        connect("")
        controller.entry.value = "llm"

        expect(press(controller.entry, "Enter").defaultPrevented).toBe(true)
      })

      it("ignores Enter while an input method is composing", () => {
        connect("")
        controller.entry.value = "ら"
        const event = new KeyboardEvent("keydown", {
          key: "Enter",
          isComposing: true,
          cancelable: true,
          bubbles: true,
        })
        controller.entry.dispatchEvent(event)

        expect(labels()).toEqual([])
        expect(event.defaultPrevented).toBe(false)
      })

      it("returns the last term to the entry on Backspace when entry is empty", () => {
        connect("one\ntwo")
        press(controller.entry, "Backspace")

        expect(labels()).toEqual(["one"])
        expect(controller.entry.value).toEqual("two")
      })

      it("leaves Backspace alone when the entry has text", () => {
        connect("one")
        controller.entry.value = "tw"
        press(controller.entry, "Backspace")

        expect(labels()).toEqual(["one"])
      })

      it("removes a term when its delete icon is activated", () => {
        connect("one\ntwo")
        press(controller.field.querySelectorAll(".delete.icon")[0], "Enter")

        expect(labels()).toEqual(["two"])
      })

      it("commits the entry on blur", () => {
        connect("")
        controller.entry.value = "llm"
        controller.entry.dispatchEvent(new FocusEvent("blur"))

        expect(labels()).toEqual(["llm"])
      })
    })

    describe("removing", () => {
      it("removes the term at the index", () => {
        connect("one\ntwo\nthree")
        controller._remove(1, false)

        expect(labels()).toEqual(["one", "three"])
      })

      it("writes the remaining terms back to the textarea", () => {
        connect("one\ntwo")
        controller._remove(0, false)

        expect(textarea.value).toEqual("two")
      })

      it("returns the term to the entry when editing", () => {
        connect("one\ntwo")
        controller._remove(1, true)

        expect(controller.entry.value).toEqual("two")
      })

      it("removes the term when its delete icon is clicked", () => {
        connect("one\ntwo")
        controller.field.querySelectorAll(".delete.icon")[0].click()

        expect(labels()).toEqual(["two"])
      })
    })
  })
})
