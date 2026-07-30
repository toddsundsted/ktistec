import { describe, expect, it, beforeEach, afterEach, vi } from "vitest"

import CriteriaInputController from "../controllers/criteria_input_controller"

describe("CriteriaInputController", () => {
  let controller
  let element
  let textarea

  const labels = () =>
    Array.from(controller.field.querySelectorAll(".ui.label")).map((label) => label.textContent)

  const labelAt = (index) => controller.field.querySelectorAll(".ui.label")[index]

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

  describe("connecting", () => {
    it("hides the textarea", () => {
      connect("")

      expect(textarea.style.display).toEqual("none")
    })

    it("renders a label for each stored term", () => {
      connect("#3dprinting\nfilament")

      expect(labels()).toEqual(["#3dprinting", "filament"])
    })

    it("classifies each label", () => {
      connect("#3dprinting\n@bob@example.com\nfilament")

      const classes = Array.from(controller.field.querySelectorAll(".ui.label")).map(
        (label) => label.className
      )

      expect(classes).toEqual(["ui label hashtag", "ui label mention", "ui label keyword"])
    })

    it("numbers the labels", () => {
      connect("one\ntwo")

      expect([labelAt(0).dataset.index, labelAt(1).dataset.index]).toEqual(["0", "1"])
    })

    it("restores the textarea", () => {
      connect("filament")
      controller.disconnect()

      expect(textarea.style.display).toEqual("")
      expect(element.querySelector(".ui.labels")).toBeNull()
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

    it("leaves an unenhanced textarea in the cache", () => {
      connect("filament")
      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(element.querySelector(".ui.labels")).toBeNull()
      expect(textarea.style.display).toEqual("")
    })

    it("leaves the terms in the textarea", () => {
      connect("filament\nresin")
      document.dispatchEvent(new Event("turbo:before-cache"))

      expect(textarea.value).toEqual("filament\nresin")
    })

    it("connects once", () => {
      connect("filament")

      expect(restore(element).querySelectorAll(".ui.labels").length).toEqual(1)
    })
  })

  describe("committing", () => {
    it("appends the entry as a term", () => {
      connect("")
      controller.entry.value = "filament"
      controller._commit()

      expect(labels()).toEqual(["filament"])
    })

    it("writes the term back to the textarea", () => {
      connect("")
      controller.entry.value = "filament"
      controller._commit()

      expect(textarea.value).toEqual("filament")
    })

    it("clears the entry", () => {
      connect("")
      controller.entry.value = "filament"
      controller._commit()

      expect(controller.entry.value).toEqual("")
    })

    it("keeps whitespace in the entry verbatim", () => {
      connect("")
      controller.entry.value = " filament"
      controller._commit()

      expect(textarea.value).toEqual(" filament")
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

  describe("removing", () => {
    it("removes the term at the index", () => {
      connect("one\ntwo\nthree")
      controller._remove(1)

      expect(labels()).toEqual(["one", "three"])
    })

    it("returns the term to the entry when editing", () => {
      connect("one\ntwo")
      controller._remove(1, { edit: true })

      expect(controller.entry.value).toEqual("two")
    })

    it("writes the remaining terms back to the textarea", () => {
      connect("one\ntwo")
      controller._remove(0)

      expect(textarea.value).toEqual("two")
    })

    it("removes the term when its delete icon is clicked", () => {
      connect("one\ntwo")
      controller.field.querySelectorAll(".delete.icon")[0].click()

      expect(labels()).toEqual(["two"])
    })

    describe("a term ahead of the tab stop", () => {
      it("brings the tab stop with it", () => {
        connect("one\ntwo\nthree\nfour")
        controller._focusTerm(2)
        controller._remove(0)

        expect(controller.focusIndex).toEqual(1)
      })

      it("leaves the tab stop on the same term", () => {
        connect("one\ntwo\nthree\nfour")
        controller._focusTerm(2)
        controller._remove(0)

        expect(labels()[controller.focusIndex]).toEqual("three")
      })
    })

    it("leaves the tab stop alone when a term after it is removed", () => {
      connect("one\ntwo\nthree")
      controller._focusTerm(0)
      controller._remove(2)

      expect(controller.focusIndex).toEqual(0)
      expect(labels()[controller.focusIndex]).toEqual("one")
    })

    it("keeps the tab stop in range when the last term is removed", () => {
      connect("one\ntwo")
      controller._focusTerm(1)
      controller._remove(1)

      expect(controller.focusIndex).toEqual(0)
    })
  })

  describe("the keyboard", () => {
    const press = (target, key, options = {}) => {
      const event = new KeyboardEvent("keydown", {
        key: key,
        cancelable: true,
        bubbles: true,
        ...options,
      })
      target.dispatchEvent(event)
      return event
    }

    describe("the entry", () => {
      it("prevents Enter from submitting the form", () => {
        connect("")
        controller.entry.value = "filament"

        expect(press(controller.entry, "Enter").defaultPrevented).toBe(true)
      })

      it("commits the entry on Enter", () => {
        connect("")
        controller.entry.value = "filament"
        press(controller.entry, "Enter")

        expect(labels()).toEqual(["filament"])
      })

      it("ignores Enter while an input method is composing", () => {
        connect("")
        controller.entry.value = "ら"
        const event = press(controller.entry, "Enter", { isComposing: true })

        expect(labels()).toEqual([])
        expect(event.defaultPrevented).toBe(false)
      })

      it("returns the last term to the entry on Backspace when the entry is empty", () => {
        connect("one\ntwo")
        press(controller.entry, "Backspace")

        expect(labels()).toEqual(["one"])
        expect(controller.entry.value).toEqual("two")
      })

      it("lets Backspace delete a character when the entry has text", () => {
        connect("one")
        controller.entry.value = "tw"

        expect(press(controller.entry, "Backspace").defaultPrevented).toBe(false)
      })

      it("commits the entry on blur", () => {
        connect("")
        controller.entry.value = "filament"
        controller.entry.dispatchEvent(new FocusEvent("blur"))

        expect(labels()).toEqual(["filament"])
      })
    })

    describe("moving focus", () => {
      it("gives the list a single tab stop", () => {
        connect("one\ntwo\nthree")

        expect([labelAt(0).tabIndex, labelAt(1).tabIndex, labelAt(2).tabIndex]).toEqual([0, -1, -1])
      })

      it("moves focus to the next term on ArrowRight", () => {
        connect("one\ntwo")
        press(labelAt(0), "ArrowRight")

        expect(document.activeElement).toEqual(labelAt(1))
      })

      it("moves focus to the previous term on ArrowLeft", () => {
        connect("one\ntwo")
        controller._focusTerm(1)
        press(labelAt(1), "ArrowLeft")

        expect(document.activeElement).toEqual(labelAt(0))
      })

      it("moves the tab stop with the focus", () => {
        connect("one\ntwo")
        press(labelAt(0), "ArrowRight")

        expect([labelAt(0).tabIndex, labelAt(1).tabIndex]).toEqual([-1, 0])
      })

      it("stops at the last term", () => {
        connect("one\ntwo")
        controller._focusTerm(1)
        press(labelAt(1), "ArrowRight")

        expect(document.activeElement).toEqual(labelAt(1))
      })

      it("moves focus to the first term on Home", () => {
        connect("one\ntwo\nthree")
        controller._focusTerm(2)
        press(labelAt(2), "Home")

        expect(document.activeElement).toEqual(labelAt(0))
      })

      it("moves focus to the last term on End", () => {
        connect("one\ntwo\nthree")
        press(labelAt(0), "End")

        expect(document.activeElement).toEqual(labelAt(2))
      })

      it("removes the focused term on Delete", () => {
        connect("one\ntwo")
        press(labelAt(0), "Delete")

        expect(labels()).toEqual(["two"])
      })

      it("keeps the focus on the list", () => {
        connect("one\ntwo\nthree")
        press(labelAt(0), "Delete")

        expect(document.activeElement).toEqual(labelAt(0))
      })

      it("falls back to the entry", () => {
        connect("one")
        press(labelAt(0), "Delete")

        expect(document.activeElement).toEqual(controller.entry)
      })
    })

    describe("reordering", () => {
      const alt = (target, key) => press(target, key, { altKey: true })

      it("moves the focused term later on Alt+ArrowDown", () => {
        connect("one\ntwo\nthree")
        alt(labelAt(0), "ArrowDown")

        expect(labels()).toEqual(["two", "one", "three"])
      })

      it("moves the focused term earlier on Alt+ArrowUp", () => {
        connect("one\ntwo\nthree")
        alt(labelAt(2), "ArrowUp")

        expect(labels()).toEqual(["one", "three", "two"])
      })

      it("writes the reordered terms back to the textarea", () => {
        connect("one\ntwo")
        alt(labelAt(0), "ArrowDown")

        expect(textarea.value).toEqual("two\none")
      })

      it("keeps focus on the term it moved", () => {
        connect("one\ntwo\nthree")
        alt(labelAt(0), "ArrowDown")

        expect(document.activeElement).toEqual(labelAt(1))
      })

      it("leaves the first term alone on Alt+ArrowUp", () => {
        connect("one\ntwo")
        alt(labelAt(0), "ArrowUp")

        expect(labels()).toEqual(["one", "two"])
      })

      it("leaves the last term alone on Alt+ArrowDown", () => {
        connect("one\ntwo")
        alt(labelAt(1), "ArrowDown")

        expect(labels()).toEqual(["one", "two"])
      })

      it("announces the move", () => {
        connect("one\ntwo")
        alt(labelAt(0), "ArrowDown")

        expect(controller.status.textContent).toEqual("Moved one to position 2 of 2")
      })

      it("lets Alt+ArrowLeft navigate back", () => {
        connect("one\ntwo")

        expect(alt(labelAt(1), "ArrowLeft").defaultPrevented).toBe(false)
      })

      it("lets Alt+ArrowRight navigate forward", () => {
        connect("one\ntwo")

        expect(alt(labelAt(0), "ArrowRight").defaultPrevented).toBe(false)
      })
    })
  })

  describe("dragging", () => {
    let scrolled

    const row = () => {
      controller.field.querySelectorAll(".ui.label").forEach((label, at) => {
        label.getBoundingClientRect = () => ({
          left: at * 100, right: at * 100 + 100,
          top: 0 - scrolled, bottom: 20 - scrolled,
        })
      })
    }

    const scrollPage = (delta) => {
      scrolled += delta
      row()
    }

    const pointer = (type, target, x, y) => {
      const event = new Event(type, { cancelable: true, bubbles: true })
      Object.assign(event, { pointerId: 1, pointerType: "mouse", button: 0, clientX: x, clientY: y })
      target.dispatchEvent(event)
      return event
    }

    const escape = () => {
      const event = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
      document.dispatchEvent(event)
      return event
    }

    const dragTo = (from, x) => {
      row()
      pointer("pointerdown", labelAt(from), from * 100, 10)
      pointer("pointermove", controller.field, x, 10)
      pointer("pointerup", controller.field, x, 10)
    }

    beforeEach(() => {
      Element.prototype.setPointerCapture = function () {}
      Element.prototype.releasePointerCapture = function () {}
      Element.prototype.hasPointerCapture = function () { return false }
      vi.stubGlobal("requestAnimationFrame", (callback) => callback())
      scrolled = 0
      Object.defineProperty(window, "scrollX", { configurable: true, get: () => 0 })
      Object.defineProperty(window, "scrollY", { configurable: true, get: () => scrolled })
    })

    afterEach(() => {
      vi.unstubAllGlobals()
    })

    it("reorders on a drop past another term", () => {
      connect("one\ntwo\nthree")
      dragTo(0, 160)

      expect(labels()).toEqual(["two", "one", "three"])
    })

    it("writes the reordered terms back to the textarea", () => {
      connect("one\ntwo")
      dragTo(0, 160)

      expect(textarea.value).toEqual("two\none")
    })

    it("moves a term to the end of the list", () => {
      connect("one\ntwo\nthree")
      dragTo(0, 290)

      expect(labels()).toEqual(["two", "three", "one"])
    })

    it("moves a term to the beginning of the list", () => {
      connect("one\ntwo\nthree")
      dragTo(2, 10)

      expect(labels()).toEqual(["three", "one", "two"])
    })

    it("renumbers the terms it reorders", () => {
      connect("one\ntwo\nthree")
      dragTo(0, 160)

      expect([labelAt(0).dataset.index, labelAt(1).dataset.index, labelAt(2).dataset.index]).toEqual([
        "0",
        "1",
        "2",
      ])
    })

    it("keeps the textarea in step across repeated moves", () => {
      connect("one\ntwo\nthree")
      row()
      pointer("pointerdown", labelAt(0), 0, 10)
      for (const x of [60, 90, 120, 150, 160, 170]) {
        row()
        pointer("pointermove", controller.field, x, 10)
      }
      pointer("pointerup", controller.field, 170, 10)

      expect(textarea.value).toEqual("two\none\nthree")
    })

    it("focuses the term a press takes hold of", () => {
      connect("one\ntwo\nthree")
      row()
      pointer("pointerdown", labelAt(1), 100, 10)
      pointer("pointerup", controller.field, 100, 10)

      expect(document.activeElement).toEqual(labelAt(1))
    })

    it("does not reorder when the pointer barely moves", () => {
      connect("one\ntwo")
      dragTo(0, 2)

      expect(labels()).toEqual(["one", "two"])
    })

    it("does not take hold of the delete icon", () => {
      connect("one\ntwo")
      pointer("pointerdown", labelAt(0).querySelector(".delete.icon"), 0, 0)

      expect(controller.drag.target).toBeNull()
    })

    it("marks the term as pressed immediately", () => {
      connect("one\ntwo")
      pointer("pointerdown", labelAt(0), 0, 0)

      expect(labelAt(0).classList).toContain("pressed")
    })

    it("clears the press when the pointer is released", () => {
      connect("one\ntwo")
      pointer("pointerdown", labelAt(0), 0, 0)
      pointer("pointerup", labelAt(0), 0, 0)

      expect(labelAt(0).classList).not.toContain("pressed")
    })

    it("marks the term being dragged", () => {
      connect("one\ntwo")
      row()
      const dragged = labelAt(0)
      pointer("pointerdown", dragged, 0, 10)
      pointer("pointermove", controller.field, 160, 10)

      expect(dragged.classList).toContain("dragging")
    })

    it("the dragged term follows the pointer's travel", () => {
      connect("one")
      pointer("pointerdown", labelAt(0), 10, 20)
      pointer("pointermove", controller.field, 40, 55)

      expect(labelAt(0).style.transform).toEqual("translate(30px, 35px)")
    })

    it("clears the offset when the drag ends", () => {
      connect("one")
      const dragged = labelAt(0)
      pointer("pointerdown", dragged, 0, 0)
      pointer("pointermove", controller.field, 40, 0)
      pointer("pointerup", controller.field, 40, 0)

      expect(dragged.style.transform).toEqual("")
    })

    it("clears the marks after the drop", () => {
      connect("one\ntwo")
      dragTo(0, 160)

      expect(controller.field.querySelectorAll(".dragging, .pressed")).toHaveLength(0)
    })

    it("reorders as the pointer crosses a term", () => {
      connect("one\ntwo")
      row()
      pointer("pointerdown", labelAt(0), 0, 10)
      pointer("pointermove", controller.field, 160, 10)

      expect(labels()).toEqual(["two", "one"])
    })

    describe("announcing", () => {
      it("announces nothing while the term is still moving", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 160, 10)

        expect(controller.status.textContent).toEqual("")
      })

      it("announces when the term lands", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        for (const x of [160, 260, 290]) {
          pointer("pointermove", controller.field, x, 10)
        }
        pointer("pointerup", controller.field, 290, 10)

        expect(controller.status.textContent).toEqual("Moved one to position 3 of 3")
      })

      it("says nothing when a term is dropped where it started", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 160, 10)
        pointer("pointermove", controller.field, 10, 10)
        pointer("pointerup", controller.field, 10, 10)

        expect(controller.status.textContent).toEqual("")
      })

      it("says nothing when the drag is cancelled", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 290, 10)
        pointer("pointercancel", controller.field, 290, 10)

        expect(controller.status.textContent).toEqual("")
      })

      it("announces every keyboard move", () => {
        connect("one\ntwo\nthree")
        const event = new KeyboardEvent("keydown", {
          key: "ArrowDown", altKey: true, cancelable: true, bubbles: true,
        })
        labelAt(0).dispatchEvent(event)

        expect(controller.status.textContent).toEqual("Moved one to position 2 of 3")
      })
    })

    describe("when the page scrolls mid-drag", () => {
      it("drops the term where the pointer is after the scroll", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 20, 10)
        scrollPage(40)
        pointer("pointermove", controller.field, 160, 10 - 40)
        pointer("pointerup", controller.field, 160, 10 - 40)

        expect(labels()).toEqual(["two", "one", "three"])
      })

      it("drops the term where the pointer is after the scroll", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 20, 10)
        scrollPage(40)
        pointer("pointermove", controller.field, 290, 10 - 40)
        pointer("pointerup", controller.field, 290, 10 - 40)

        expect(labels()).toEqual(["two", "three", "one"])
      })
    })

    describe("when the drag is cancelled", () => {
      const abandon = () => {
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 290, 10)
        pointer("pointercancel", controller.field, 290, 10)
      }

      it("puts the term back", () => {
        connect("one\ntwo\nthree")
        abandon()

        expect(labels()).toEqual(["one", "two", "three"])
        expect(textarea.value).toEqual("one\ntwo\nthree")
      })

      it("puts the tab stop back", () => {
        connect("one\ntwo\nthree")
        controller._focusTerm(1)
        abandon()

        expect([labelAt(0).tabIndex, labelAt(1).tabIndex, labelAt(2).tabIndex]).toEqual([0, -1, -1])
      })

      it("puts the focus back", () => {
        connect("one\ntwo\nthree")
        controller._focusTerm(1)
        abandon()

        expect(document.activeElement).toEqual(labelAt(0))
      })
    })

    describe("when Escape is pressed", () => {
      it("puts the term back", () => {
        connect("one\ntwo\nthree")
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        pointer("pointermove", controller.field, 290, 10)
        escape()

        expect(labels()).toEqual(["one", "two", "three"])
      })
    })

    // type a term and then, without committing it, grab one of the
    // terms already there. pressing a label moves focus to it, the
    // entry commits what was typed as it loses focus, and the list is
    // rebuilt -- so the press ends up holding a label that is no
    // longer part of the list. it takes hold of the label that
    // replaced it, and the drag continues.
    describe("when the entry holds uncommitted text", () => {
      const pressATerm = () => {
        row()
        pointer("pointerdown", labelAt(0), 0, 10)
        controller.entry.value = "three"
        controller.entry.dispatchEvent(new FocusEvent("blur"))
        row()
      }

      const dragAndDrop = () => {
        pointer("pointermove", controller.field, 160, 10)
        pointer("pointerup", controller.field, 160, 10)
      }

      it("commits what was typed", () => {
        connect("one\ntwo")
        pressATerm()

        expect(labels()).toEqual(["one", "two", "three"])
      })

      it("renders each term once", () => {
        connect("one\ntwo")
        pressATerm()
        dragAndDrop()

        expect(labels()).toEqual(["two", "one", "three"])
      })

      it("writes each term once to the textarea", () => {
        connect("one\ntwo")
        pressATerm()
        dragAndDrop()

        expect(textarea.value).toEqual("two\none\nthree")
      })

      it("lets the press become a drag", () => {
        connect("one\ntwo")
        pressATerm()

        expect(controller.drag.target).toEqual(labelAt(0))
      })

      it("keeps what was typed when the drag is cancelled", () => {
        connect("one\ntwo")
        pressATerm()
        pointer("pointermove", controller.field, 160, 10)
        escape()

        expect(labels()).toEqual(["one", "two", "three"])
        expect(textarea.value).toEqual("one\ntwo\nthree")
      })
    })
  })
})
