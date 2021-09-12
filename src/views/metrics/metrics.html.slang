- content_for "head" do
  script src="/dist/chart.bundle.js"
crystal:
  colors = [
    "#619ED6",
    "#6BA547",
    "#F7D027",
    "#E48F1B",
    "#B77EA3",
    "#E64345"
  ].each.cycle
  labels = Chart.labels(*range, granularity: granularity)
  datasets = charts.map do |chart|
    {
      label: chart.name,
      data: chart.data(*range, granularity: granularity),
      borderColor: (color = colors.next.to_s),
      backgroundColor: "#{color}80"
    }
  end
canvas#charts
script#chart-labels type="application/json"
  == labels.to_json
script#chart-datasets type="application/json"
  == datasets.to_json
script
  | let ctx = document.getElementById("charts").getContext("2d")
    let crt = new Chart(ctx, {
      data: {
        labels: JSON.parse(document.getElementById("chart-labels").textContent),
        datasets: JSON.parse(document.getElementById("chart-datasets").textContent)
      },
      type: "line",
      tension: 0.1,
      spanGaps: false
    })
