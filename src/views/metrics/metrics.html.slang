- content_for "head" do
  meta name="turbo-cache-control" content="no-cache"
- content_for "title" do
  | Metrics
crystal:
  colors = [
    "#619ED6",
    "#6BA547",
    "#F7D027",
    "#E48F1B",
    "#B77EA3",
    "#E64345"
  ].each.cycle
crystal:
  datasets = charts.select(&.name.starts_with?(/inbox-|outbox-/)).map do |chart|
    {
      label: chart.name,
      data: chart.data(*range, granularity: granularity),
      borderColor: (color = colors.next.to_s),
      backgroundColor: "#{color}80",
      type: "line",
      tension: 0.1,
      spanGaps: false
    }
  end
canvas#charts-1 data-controller="chart"
  script#chart-labels-1 type="application/json" data-chart-target="labels"
    == labels.to_json
  script#chart-datasets-1 type="application/json" data-chart-target="datasets"
    == datasets.to_json
crystal:
  datasets = charts.select(&.name.starts_with?(/heap-|free-|sqlite-/)).map do |chart|
    {
      label: chart.name,
      data: chart.data(*range, granularity: granularity, predicate: MetricsController::Chart::Predicate::Average),
      borderColor: (color = colors.next.to_s),
      backgroundColor: "#{color}80",
      type: "line",
      tension: 0.1,
      spanGaps: false
    }
  end
  datasets += charts.select(&.name.starts_with?(/server-/)).map do |chart|
    {
      label: chart.name,
      data: chart.data(*range, granularity: granularity, predicate: MetricsController::Chart::Predicate::Summate),
      borderColor: (color = colors.next.to_s),
      backgroundColor: "#{color}80",
      type: "line",
      showLine: false,
      pointStyle: "triangle",
      pointRadius: 4
    }
  end
canvas#charts-2 data-controller="chart"
  script#chart-labels-2 type="application/json" data-chart-target="labels"
    == labels.to_json
  script#chart-datasets-2 type="application/json" data-chart-target="datasets"
    == datasets.to_json
crystal:
  ranges = {
    7.days.ago.to_s("%Y-%m-%d") => "Last 7 Days",
    30.days.ago.to_s("%Y-%m-%d") => "Last 30 Days",
    365.days.ago.to_s("%Y-%m-%d") => "Last 365 Days",
    "" => "All Time",
  }
  granularities = {
    "daily" => "By Day",
    "weekly" => "By Week",
    "monthly" => "By Month",
  }
== form_tag(nil, "/metrics", method: "GET", class: "ui mini form") do
  .two.fields
    == select_tag("Range", nil, :begin, ranges, range.first.try(&.to_s("%Y-%m-%d")))
    == select_tag("Granularity", nil, :granularity, granularities, granularity.to_s.split("::").last.downcase)
  == submit_button("Update", class: "ui mini primary button")
br.transition.hidden
