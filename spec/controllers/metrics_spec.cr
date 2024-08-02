require "../../src/controllers/metrics"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe MetricsController::Chart do
  setup_spec

  alias Granularity = MetricsController::Chart::Granularity
  alias Predicate = MetricsController::Chart::Predicate

  describe ".labels" do
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

    it "returns the summated data at weekly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Weekly)).to eq({"2016-12-26" => 3, "2017-01-02" => 3})
    end

    it "returns the summated data at monthly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Monthly)).to eq({"2016-12-01" => 1, "2017-01-01" => 5})
    end

    it "returns the summated data at yearly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Yearly)).to eq({"2016-01-01" => 1, "2017-01-01" => 5})
    end

    it "returns the averaged data at daily granularity" do
      expect(subject.data(from, to, predicate: Predicate::Average)).to eq({"2016-12-31" => 1, "2017-01-01" => 2, "2017-01-02" => 3})
    end

    it "returns the averaged data at weekly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Weekly, predicate: Predicate::Average)).to eq({"2016-12-26" => 1, "2017-01-02" => 3})
    end

    it "returns the averaged data at monthly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Monthly, predicate: Predicate::Average)).to eq({"2016-12-01" => 1, "2017-01-01" => 2})
    end

    it "returns the averaged data at yearly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Yearly, predicate: Predicate::Average)).to eq({"2016-01-01" => 1, "2017-01-01" => 2})
    end

    it "returns an empty collection" do
      expect(subject.data(nil, nil)).to be_empty
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
        get "/metrics", ACCEPT_HTML
        expect(XML.parse_html(response.body).xpath_nodes("//canvas[@id='charts-1']")).not_to be_empty
      end

      it "renders metrics labels" do
        get "/metrics", ACCEPT_HTML
        labels = JSON.parse(XML.parse_html(response.body).xpath_nodes("//script[@id='chart-labels-1']").first.text).as_a
        expect(labels).to contain_exactly("2016-02-15")
      end

      it "renders metrics datasets" do
        get "/metrics", ACCEPT_HTML
        datasets = JSON.parse(XML.parse_html(response.body).xpath_nodes("//script[@id='chart-datasets-1']").first.text).as_a
        expect(datasets.map(&.dig("label"))).to contain_exactly("inbox-test-chart")
        expect(datasets.map(&.dig("data"))).to contain_exactly({"2016-02-15" => 15})
      end

      it "renders metrics data" do
        get "/metrics", ACCEPT_JSON
        datasets = JSON.parse(response.body).as_a
        expect(datasets.map(&.dig("label"))).to contain_exactly("inbox-test-chart")
        expect(datasets.map(&.dig("data"))).to contain_exactly({"2016-02-15" => 15})
      end
    end
  end
end
