import { describe, expect, it, beforeEach } from "vitest"
import DropdownController from "../controllers/dropdown_controller"

describe("DropdownController", () => {
  let controller
  let element
  let menu

  beforeEach(() => {
    element = document.createElement("div")
    menu = document.createElement("div")
    menu.className = "menu"
    element.appendChild(menu)

    controller = Object.create(DropdownController.prototype)
    Object.defineProperty(controller, "element", {
      value: element,
      writable: true,
      configurable: true,
    })
  })

  it("shows menu when hidden and clicking the element", () => {
    controller.click({ target: element })

    expect(menu.style.display).toBe("block")
  })

  it("hides menu when visible and clicking the element", () => {
    menu.style.display = "block"

    controller.click({ target: element })

    expect(menu.style.display).toBe("")
  })

  it("does not toggle menu when clicking inside the menu", () => {
    menu.style.display = "block"
    const innerItem = document.createElement("a")
    menu.appendChild(innerItem)

    controller.click({ target: innerItem })

    expect(menu.style.display).toBe("block")
  })

  it("shows menu when clicking outside the menu but within the element", () => {
    const sibling = document.createElement("span")
    element.appendChild(sibling)

    controller.click({ target: sibling })

    expect(menu.style.display).toBe("block")
  })
})
