import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return [ "labels", "datasets", "options" ]
  }

  async connect() {
    let Chart = (await import("chart.js/auto")).default
    const config = {
      data: {
        labels: JSON.parse(this.labelsTarget.textContent),
        datasets: JSON.parse(this.datasetsTarget.textContent)
      }
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
