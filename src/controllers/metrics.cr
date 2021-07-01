require "../framework/controller"
require "../models/point"

class MetricsController
  include Ktistec::Controller

  class Chart
    property name : String
    property points : Array(Point)

    def initialize(@name, @points)
    end

    enum Granularity
      Daily
      Weekly
      Monthly
      Yearly
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

    def data(begin _begin, end _end, granularity : Granularity = Granularity::Daily)
      points.reduce(Hash(Time, Int32).new(0)) do |data, point|
        if _begin && point.timestamp >= _begin && _end && point.timestamp <= _end
          case granularity
          in Granularity::Daily
            data[point.timestamp.at_beginning_of_day] += point.value
          in Granularity::Weekly
            data[point.timestamp.at_beginning_of_week] += point.value
          in Granularity::Monthly
            data[point.timestamp.at_beginning_of_month] += point.value
          in Granularity::Yearly
            data[point.timestamp.at_beginning_of_year] += point.value
          end
        end
        data
      end.transform_keys(&.to_s("%Y-%m-%d"))
    end
  end
end
