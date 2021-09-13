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
  timezone = Time::Location.load(env.account.timezone)
  now = Time.utc.in(timezone)
  ranges = {
    "" => "",
    now.at_beginning_of_week.to_s("%Y-%m-%d") => "This Week",
    now.at_beginning_of_month.to_s("%Y-%m-%d") => "This Month",
    now.at_beginning_of_year.to_s("%Y-%m-%d") => "This Year"
  }
  granularities = {
    "" => "",
    "daily" => "By Day",
    "weekly" => "By Week",
    "monthly" => "By Month"
  }
script#chart-labels type="application/json"
  == labels.to_json
script#chart-datasets type="application/json"
  == datasets.to_json
canvas#charts
== form_tag(nil, "/metrics", "GET", class: "ui mini form", data: {turbo: "false"}) do
  .two.fields
    == select_tag("Range", nil, :begin, ranges, env.params.query["begin"]?)
    == select_tag("Granularity", nil, :granularity, granularities, env.params.query["granularity"]?)
  input.ui.mini.primary.button type="submit" value="Update"
br
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
