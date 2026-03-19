import { describe, expect, it } from "vitest"
import DefaultLanguageController from "../controllers/default_language_controller"

describe("DefaultLanguageController", () => {
  const language = navigator.language

  it("sets placeholder to detected language", () => {
    const element = document.createElement("input")

    DefaultLanguageController.prototype.connect.call({ element })

    expect(element.getAttribute("placeholder")).toContain(language)
  })

  it("sets value to detected language when field is empty", () => {
    const element = document.createElement("input")

    DefaultLanguageController.prototype.connect.call({ element })

    expect(element.value).toBe(language)
  })

  it("does not set value when placeholder-only is set", () => {
    const element = document.createElement("input")
    element.setAttribute("data-placeholder-only", "true")
    element.value = "fr-FR"

    DefaultLanguageController.prototype.connect.call({ element })

    expect(element.getAttribute("placeholder")).toContain(language)
    expect(element.value).toBe("fr-FR")
  })

  it("does not overwrite an existing value", () => {
    const element = document.createElement("input")
    element.value = "fr-FR"

    DefaultLanguageController.prototype.connect.call({ element })

    expect(element.value).toBe("fr-FR")
  })

  it("does not set value when field is inside a .field.error element", () => {
    const fieldError = document.createElement("div")
    fieldError.className = "field error"
    const element = document.createElement("input")
    fieldError.appendChild(element)

    DefaultLanguageController.prototype.connect.call({ element })

    expect(element.value).toBe("")
  })
})
