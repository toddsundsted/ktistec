require "../framework/controller"
require "../models/point"

class MetricsController
  include Ktistec::Controller

  class Chart
    property name : String
    property points : Array(Point)
    private getter timezone : Time::Location

    def initialize(@name, @points, @timezone)
    end

    enum Granularity
      Daily
      Weekly
      Monthly
      Yearly
    end

    enum Predicate
      Summate
      Average
    end

    def self.labels(begin _begin, end _end, granularity : Granularity = Granularity::Daily)
      Array(String).new.tap do |result|
        if _begin && _end
          case granularity
          in Granularity::Daily
            current = _begin.at_beginning_of_day
          in Granularity::Weekly
            current = _begin.at_beginning_of_week
          in Granularity::Monthly
            current = _begin.at_beginning_of_month
          in Granularity::Yearly
            current = _begin.at_beginning_of_year
          end
          while (current <= _end)
            result << current.to_s("%Y-%m-%d")
            case granularity
            in Granularity::Daily
              current = current.shift(days: 1)
            in Granularity::Weekly
              current = current.shift(weeks: 1)
            in Granularity::Monthly
              current = current.shift(months: 1)
            in Granularity::Yearly
              current = current.shift(years: 1)
            end
          end
        end
      end
    end

    def data(begin _begin, end _end, granularity : Granularity = Granularity::Daily, predicate : Predicate = Predicate::Summate)
      points.reduce(Hash(Time, {Int32, Int32}).new({0, 0})) do |data, point|
        if _begin && point.timestamp >= _begin && _end && point.timestamp <= _end
          key =
            case granularity
            in Granularity::Daily
              point.timestamp.in(timezone).at_beginning_of_day
            in Granularity::Weekly
              point.timestamp.in(timezone).at_beginning_of_week
            in Granularity::Monthly
              point.timestamp.in(timezone).at_beginning_of_month
            in Granularity::Yearly
              point.timestamp.in(timezone).at_beginning_of_year
            end
          data[key] = {data[key][0] + point.value, data[key][1] + 1}
        end
        data
      end.transform_values do |value|
        case predicate
        in Predicate::Summate
          value[0]
        in Predicate::Average
          (value[0] / value[1]).to_i32
        end
      end.transform_keys(&.to_s("%Y-%m-%d"))
    end
  end

  alias Granularity = Chart::Granularity
  alias Predicate = Chart::Predicate

  private macro timezone(env)
    Time::Location.load({{env}}.account.timezone)
  end

  get "/metrics" do |env|
    range = get_range(env)
    granularity = get_granularity(env)

    charts = Point.charts.select(&.starts_with?(/inbox-|outbox-|heap-|server-/)).map do |chart|
      Chart.new(
        name: chart,
        points: Point.chart(chart, *range),
        timezone: timezone(env)
      )
    end

    minmax = charts.flat_map(&.points).map(&.timestamp).minmax?

    range = {range[0] || minmax[0], range[1] || minmax[1]}

    labels = Chart.labels(*range, granularity: granularity)

    ok "metrics/metrics"
  end

  private def self.get_range(env)
    timezone = timezone(env)
    if (_begin = env.params.query["begin"]?.try(&.presence))
      _begin = Time.parse(_begin, "%Y-%m-%d", timezone)
    end
    if (_end = env.params.query["end"]?.try(&.presence))
      _end = Time.parse(_end, "%Y-%m-%d", timezone)
    end
    {_begin, _end}
  end

  private def self.get_granularity(env, default = Granularity::Daily)
    if (granularity = env.params.query["granularity"]?.try(&.presence))
      granularity = Granularity.parse?(granularity)
    end
    granularity || default
  end
end
