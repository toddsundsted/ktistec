require "../../src/models/point"

require "../spec_helper/model"

Spectator.describe Point do
  setup_spec

  macro create_point!(index, chart = "foo-bar-chart")
    let!(point{{index}}) do
      described_class.new(
        chart: {{chart}},
        timestamp: Time.utc(2016, 2, 15, 10, 20, {{index}}),
        value: {{index}}
      ).save
    end
  end

  create_point!(1, "foo-baz-chart")
  create_point!(2, "fee-fi-fo-fum-chart")
  create_point!(3)
  create_point!(4)
  create_point!(5)

  describe ".charts" do
    it "returns the names of all charts" do
      expect(described_class.charts).to have("foo-bar-chart", "foo-baz-chart", "fee-fi-fo-fum-chart")
    end
  end

  describe ".chart" do
    it "returns the points in the chart" do
      expect(described_class.chart("foo-bar-chart")).to eq([point3, point4, point5])
    end

    it "returns the points before the ending of the range" do
      expect(described_class.chart("foo-bar-chart", end: point4.timestamp)).to eq([point3, point4])
    end

    it "returns the points after the beginning of the range" do
      expect(described_class.chart("foo-bar-chart", begin: point4.timestamp)).to eq([point4, point5])
    end

    it "does not return points not in the chart" do
      expect(described_class.chart("null-chart")).to be_empty
    end
  end
end
