import { describe, expect, it, beforeEach, vi } from "vitest"

vi.mock("chart.js/auto", () => {
  const ChartMock = vi.fn().mockImplementation(function (ctx, config) {
    this.config = config
    this.destroy = vi.fn()
  })
  ChartMock.register = vi.fn()
  return { default: ChartMock }
})

import ChartController from "../controllers/chart_controller"

describe("ChartController", () => {
  let controller

  beforeEach(() => {
    controller = Object.create(ChartController.prototype)
  })

  describe("disconnect", () => {
    it("destroys the chart instance", () => {
      const destroySpy = vi.fn()
      controller.chart = { destroy: destroySpy }

      controller.disconnect()

      expect(destroySpy).toHaveBeenCalled()
    })
  })

  describe("connect", () => {
    it("creates a chart with parsed labels and datasets", async () => {
      const canvas = document.createElement("canvas")
      canvas.getContext = vi.fn().mockReturnValue({})

      const labelsTarget = document.createElement("script")
      labelsTarget.textContent = JSON.stringify(["Jan", "Feb", "Mar"])

      const datasetsTarget = document.createElement("script")
      datasetsTarget.textContent = JSON.stringify([
        { label: "views", data: { Jan: 10, Feb: 20, Mar: 30 } },
      ])

      Object.defineProperty(controller, "element", {
        value: canvas,
        writable: true,
        configurable: true,
      })
      controller.labelsTarget = labelsTarget
      controller.datasetsTarget = datasetsTarget
      controller.hasOptionsTarget = false

      await controller.connect()

      expect(controller.chart).toBeDefined()
      expect(controller.chart.config.data.labels).toEqual(["Jan", "Feb", "Mar"])
      expect(controller.chart.config.data.datasets).toHaveLength(1)
    })

    it("includes options when the options target is present", async () => {
      const canvas = document.createElement("canvas")
      canvas.getContext = vi.fn().mockReturnValue({})

      const labelsTarget = document.createElement("script")
      labelsTarget.textContent = JSON.stringify([])

      const datasetsTarget = document.createElement("script")
      datasetsTarget.textContent = JSON.stringify([])

      const optionsTarget = document.createElement("script")
      optionsTarget.textContent = JSON.stringify({ responsive: true })

      Object.defineProperty(controller, "element", {
        value: canvas,
        writable: true,
        configurable: true,
      })
      controller.labelsTarget = labelsTarget
      controller.datasetsTarget = datasetsTarget
      controller.optionsTarget = optionsTarget
      controller.hasOptionsTarget = true

      await controller.connect()

      expect(controller.chart.config.options).toEqual({ responsive: true })
    })
  })
})
