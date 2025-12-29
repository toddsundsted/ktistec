import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "labels", "datasets", "options" ]
  }

  async connect() {
    let Chart = (await import("chart.js/auto")).default

    const verticalLinePlugin = {
      id: 'verticalLinePlugin',

      afterDraw: (chart) => {
        const { ctx, chartArea, scales } = chart
        if (!chartArea || !scales.x) {
          return
        }

        chart.data.datasets.forEach((dataset) => {
          if (dataset.label == 'server-start') {
            if (!dataset.data) {
              return
            }

            const borderColor = dataset.borderColor || '#7A7A7A'
            const labels = chart.data.labels || []

            labels.forEach((label) => {
              const value = dataset.data[label]
              if (!value || value === 0) {
                return
              }

              const x = scales.x.getPixelForValue(label)

              ctx.save()
              ctx.strokeStyle = borderColor
              ctx.lineWidth = 1
              ctx.setLineDash([4, 4])
              ctx.beginPath()
              ctx.moveTo(x, chartArea.top)
              ctx.lineTo(x, chartArea.bottom)
              ctx.stroke()
              ctx.restore()
            })
          }
        })
      }
    }

    Chart.register(verticalLinePlugin)

    const config = {
      data: {
        labels: JSON.parse(this.labelsTarget.textContent),
        datasets: JSON.parse(this.datasetsTarget.textContent)
      },
      plugins: [verticalLinePlugin]
    }

    if (this.hasOptionsTarget) {
      config.options = JSON.parse(this.optionsTarget.textContent)
    }

    this.chart = new Chart(this.element.getContext("2d"), config)
  }

  disconnect() {
    this.chart.destroy()
  }
}
