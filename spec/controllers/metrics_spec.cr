require "../../src/controllers/metrics"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe MetricsController::Chart do
  setup_spec

  alias Granularity = MetricsController::Chart::Granularity
  alias Predicate = MetricsController::Chart::Predicate

  describe ".labels" do
    it "returns the labels at hourly granularity" do
      from_hour = Time.utc(2017, 1, 1, 10, 0, 0)
      to_hour = Time.utc(2017, 1, 1, 13, 0, 0)
      expect(subject.labels(from_hour, to_hour, granularity: Granularity::Hourly)).to eq([
        "2017-01-01 10:00", "2017-01-01 11:00", "2017-01-01 12:00", "2017-01-01 13:00"
      ])
    end

    let(from) { Time.utc(2016, 12, 31) }
    let(to) { Time.utc(2017, 1, 2) }

    subject { described_class }

    it "returns the labels at daily granularity" do
      expect(subject.labels(from, to)).to eq(["2016-12-31", "2017-01-01", "2017-01-02"])
    end

    it "returns the labels at weekly granularity" do
      expect(subject.labels(from, to, granularity: Granularity::Weekly)).to eq(["2016-12-26", "2017-01-02"])
    end

    it "returns the labels at monthly granularity" do
      expect(subject.labels(from, to, granularity: Granularity::Monthly)).to eq(["2016-12-01", "2017-01-01"])
    end

    it "returns the labels at yearly granularity" do
      expect(subject.labels(from, to, granularity: Granularity::Yearly)).to eq(["2016-01-01", "2017-01-01"])
    end

    it "returns an empty collection" do
      expect(subject.labels(nil, nil)).to be_empty
    end
  end

  describe "#data" do
    it "returns the summated data at hourly granularity" do
      from_hour = Time.utc(2017, 1, 1, 10, 0, 0)
      to_hour = Time.utc(2017, 1, 1, 12, 0, 0)
      points = [
        Point.new(chart: "test-chart", timestamp: Time.utc(2017, 1, 1, 10, 30, 0), value: 5),
        Point.new(chart: "test-chart", timestamp: Time.utc(2017, 1, 1, 11, 15, 0), value: 10),
        Point.new(chart: "test-chart", timestamp: Time.utc(2017, 1, 1, 11, 45, 0), value: 15)
      ]
      hourly_chart = described_class.new("test-chart", points, Time::Location::UTC)
      expect(hourly_chart.data(from_hour, to_hour, granularity: Granularity::Hourly)).to eq({
        "2017-01-01 10:00" => 5, "2017-01-01 11:00" => 25
      })
    end

    it "returns the averaged data at hourly granularity" do
      from_hour = Time.utc(2017, 1, 1, 10, 0, 0)
      to_hour = Time.utc(2017, 1, 1, 11, 0, 0)
      points = [
        Point.new(chart: "test-chart", timestamp: Time.utc(2017, 1, 1, 10, 15, 0), value: 10),
        Point.new(chart: "test-chart", timestamp: Time.utc(2017, 1, 1, 10, 45, 0), value: 20)
      ]
      hourly_chart = described_class.new("test-chart", points, Time::Location::UTC)
      expect(hourly_chart.data(from_hour, to_hour, granularity: Granularity::Hourly, predicate: Predicate::Average)).to eq({
        "2017-01-01 10:00" => 15
      })
    end

    let(from) { Time.utc(2016, 12, 31) }
    let(to) { Time.utc(2017, 1, 2) }

    macro create_point!(index)
      let_create!(
        :point, named: point{{index}},
        chart: "test-chart",
        timestamp: Time.utc(2016, 12, 30) + {{index}}.days,
        value: {{index}}
      )
    end

    create_point!(1)
    create_point!(2)
    create_point!(3)

    subject { described_class.new("test-chart", [point1, point2, point3], Time::Location::UTC) }

    it "returns the summated data at daily granularity" do
      expect(subject.data(from, to)).to eq({"2016-12-31" => 1, "2017-01-01" => 2, "2017-01-02" => 3})
    end

    it "returns the averaged data at daily granularity" do
      expect(subject.data(from, to, predicate: Predicate::Average)).to eq({"2016-12-31" => 1, "2017-01-01" => 2, "2017-01-02" => 3})
    end

    it "returns the summated data at weekly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Weekly)).to eq({"2016-12-26" => 3, "2017-01-02" => 3})
    end

    it "returns the averaged data at weekly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Weekly, predicate: Predicate::Average)).to eq({"2016-12-26" => 1, "2017-01-02" => 3})
    end

    it "returns the summated data at monthly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Monthly)).to eq({"2016-12-01" => 1, "2017-01-01" => 5})
    end

    it "returns the averaged data at monthly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Monthly, predicate: Predicate::Average)).to eq({"2016-12-01" => 1, "2017-01-01" => 2})
    end

    it "returns the summated data at yearly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Yearly)).to eq({"2016-01-01" => 1, "2017-01-01" => 5})
    end

    it "returns the averaged data at yearly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Yearly, predicate: Predicate::Average)).to eq({"2016-01-01" => 1, "2017-01-01" => 2})
    end

    it "returns an empty collection" do
      expect(subject.data(nil, nil)).to be_empty
    end

    # SEE: https://github.com/crystal-lang/crystal/issues/16112

    context "DST bug" do
      let(bug_time) { Time.parse("2024-11-04 04:34:08.000", "%Y-%m-%d %H:%M:%S.%L", Time::Location::UTC) }
      let(ny_tz) { Time::Location.load("America/New_York") }

      # when the following test starts to fail, we know the bug has
      # been fixed and the workaround can be removed.

      it "returns tuesday" do
        beginning_of_week = bug_time.in(ny_tz).at_beginning_of_week
        expect(beginning_of_week.day_of_week).to eq(Time::DayOfWeek::Tuesday)
      end

      describe ".safe_at_beginning_of_week" do
        it "returns monday" do
          beginning_of_week = described_class.safe_at_beginning_of_week(bug_time.in(ny_tz))
          expect(beginning_of_week.day_of_week).to eq(Time::DayOfWeek::Monday)
        end
      end

      # include the DST transition

      let(from) { Time.parse("2024-10-01", "%Y-%m-%d", ny_tz) }
      let(to) { Time.parse("2024-12-01", "%Y-%m-%d", ny_tz) }

      let_create!(
        point,
        named: dst_point,
        chart: "heap-size",
        timestamp: bug_time,
        value: 1000
      )

      subject { described_class.new("heap-size", [dst_point], ny_tz) }

      it "correctly handles dates at DST transitions at weekly granularity" do
        data = subject.data(from, to, granularity: Granularity::Weekly)
        expect(data.keys).not_to contain("2024-10-29")
        expect(data.keys).to contain("2024-10-28")
      end
    end
  end
end

Spectator.describe MetricsController do
  setup_spec

  ACCEPT_HTML = HTTP::Headers{"Accept" => "text/html"}
  ACCEPT_JSON = HTTP::Headers{"Accept" => "application/json"}

  describe "GET /metrics" do
    it "returns 401 if not authorized" do
      get "/metrics", ACCEPT_HTML
      expect(response.status_code).to eq(401)
    end

    it "returns 401 if not authorized" do
      get "/metrics", ACCEPT_JSON
      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in

      it "succeeds" do
        get "/metrics", ACCEPT_HTML
        expect(response.status_code).to eq(200)
      end

      it "succeeds" do
        get "/metrics", ACCEPT_JSON
        expect(response.status_code).to eq(200)
      end

      macro create_point!(index)
        let_create!(
          :point, named: point{{index}},
          chart: "inbox-test-chart",
          timestamp: Time.utc(2016, 2, 15, 10, 20, {{index}}),
          value: {{index}}
        )
      end

      create_point!(1)
      create_point!(2)
      create_point!(3)
      create_point!(4)
      create_point!(5)

      it "renders metrics chart" do
        get "/metrics?begin=", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//canvas[@id='charts-1']")).not_to be_empty
      end

      it "renders metrics labels" do
        get "/metrics?begin=", ACCEPT_HTML
        labels = JSON.parse(XML.parse_html(response.body).xpath_nodes("//script[@id='chart-labels-1']").first.text).as_a
        expect(labels).to contain_exactly("2016-02-15")
      end

      it "renders metrics datasets" do
        get "/metrics?begin=", ACCEPT_HTML
        datasets = JSON.parse(XML.parse_html(response.body).xpath_nodes("//script[@id='chart-datasets-1']").first.text).as_a
        expect(datasets.map(&.dig("label"))).to contain_exactly("inbox-test-chart")
        expect(datasets.map(&.dig("data"))).to contain_exactly({"2016-02-15" => 15})
      end

      it "renders metrics data" do
        get "/metrics?begin=", ACCEPT_JSON
        datasets = JSON.parse(response.body).as_a
        expect(datasets.map(&.dig("label"))).to contain_exactly("inbox-test-chart")
        expect(datasets.map(&.dig("data"))).to contain_exactly({"2016-02-15" => 15})
      end

      context "with an older chart" do
        let_create!(
          :point, named: point_empty_chart,
          chart: "inbox-older-chart",
          timestamp: Time.utc(2010, 1, 1, 0, 0, 0),
          value: 0
        )

        it "ignores charts with no points in the date range" do
          get "/metrics?begin=2016-01-01&end=2017-01-01", ACCEPT_JSON
          datasets = JSON.parse(response.body).as_a
          expect(datasets.map(&.dig("label"))).to contain_exactly("inbox-test-chart")
          expect(datasets.map(&.dig("label"))).not_to contain("inbox-older-chart")
        end

        it "ignores all charts when no points in the date range" do
          get "/metrics?begin=2020-01-01&end=2020-01-31", ACCEPT_JSON
          datasets = JSON.parse(response.body).as_a
          expect(datasets).to be_empty
        end
      end
    end
  end
end
