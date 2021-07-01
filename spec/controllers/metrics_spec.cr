require "../../src/controllers/metrics"

require "../spec_helper/controller"

Spectator.describe MetricsController::Chart do
  setup_spec

  alias Granularity = MetricsController::Chart::Granularity

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
      let!(point{{index}}) do
        Point.new(
          chart: "test-chart",
          timestamp: Time.utc(2016, 12, 30) + {{index}}.days,
          value: {{index}}
        ).save
      end
    end

    create_point!(1)
    create_point!(2)
    create_point!(3)

    subject { described_class.new("test-chart", [point1, point2, point3]) }

    it "returns the data at daily granularity" do
      expect(subject.data(from, to)).to eq({"2016-12-31" => 1, "2017-01-01" => 2, "2017-01-02" => 3})
    end

    it "returns the data at weekly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Weekly)).to eq({"2016-12-26" => 3, "2017-01-02" => 3})
    end

    it "returns the data at monthly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Monthly)).to eq({"2016-12-01" => 1, "2017-01-01" => 5})
    end

    it "returns the data at yearly granularity" do
      expect(subject.data(from, to, granularity: Granularity::Yearly)).to eq({"2016-01-01" => 1, "2017-01-01" => 5})
    end

    it "returns an empty collection" do
      expect(subject.data(nil, nil)).to be_empty
    end
  end
end
