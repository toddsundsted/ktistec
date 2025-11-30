import { describe, expect, it } from "vitest"
import LocalTimezoneController from "../controllers/local_timezone_controller"

describe("local_timezone_controller", () => {
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone

  it("sets placeholder and value to the detected timezone", () => {
    const element = document.createElement("input")

    LocalTimezoneController.prototype.connect.call({ element })

    expect(element.getAttribute("placeholder")).toContain(timezone)
    expect(element.value).toBe(timezone)
  })

  it("does not overwrite value when placeholder-only is set", () => {
    const element = document.createElement("input")
    element.dataset.placeholderOnly = "true"
    element.value = "Foo/Bar"

    LocalTimezoneController.prototype.connect.call({ element })

    expect(element.getAttribute("placeholder")).toContain(timezone)
    expect(element.value).toBe("Foo/Bar")
  })
})
