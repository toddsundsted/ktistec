- content_for "head" do
  meta name="turbo-cache-control" content="no-cache"
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
canvas#charts data-controller="chart"
  script#chart-labels type="application/json" data-chart-target="labels"
    == labels.to_json
  script#chart-datasets type="application/json" data-chart-target="datasets"
    == datasets.to_json
== form_tag(nil, "/metrics", "GET", class: "ui mini form") do
  .two.fields
    == select_tag("Range", nil, :begin, ranges, env.params.query["begin"]?)
    == select_tag("Granularity", nil, :granularity, granularities, env.params.query["granularity"]?)
  input.ui.mini.primary.button type="submit" value="Update"
br.transition.hidden
