require "../framework/model"
require "../framework/model/**"

# Data point.
#
class Point
  include Ktistec::Model

  @[Persistent]
  property chart : String

  @[Persistent]
  property timestamp : Time { Time.utc }

  @[Persistent]
  property value : Int32

  def self.charts
    query = <<-QUERY
      SELECT DISTINCT chart
        FROM points
    QUERY
    Internal.log_query(query) do
      Ktistec.database.query_all(query, as: String)
    end
  end

  def self.chart(chart, begin _begin = nil, end _end = nil)
    query = <<-QUERY
      SELECT #{Point.columns(prefix: "p")}
        FROM points AS p
       WHERE p.chart = ?
        #{_begin ? "AND p.timestamp >= ?" : ""}
        #{_end ? "AND p.timestamp <= ?" : ""}
    ORDER BY p.timestamp ASC
    QUERY
    if _begin && _end
      Point.query_all(query, chart, _begin, _end)
    elsif _begin
      Point.query_all(query, chart, _begin)
    elsif _end
      Point.query_all(query, chart, _end)
    else
      Point.query_all(query, chart)
    end
  end
end
