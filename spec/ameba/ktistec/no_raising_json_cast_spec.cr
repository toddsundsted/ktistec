require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/no_raising_json_cast"

Spectator.describe Ameba::Rule::Ktistec::NoRaisingJsonCast do
  let(rule) { described_class.new }

  let(path) { "src/models/activity_pub/example.cr" }

  def test(code, path = path)
    Ameba::Source.new(code, path).tap { |source| rule.test(source) }
  end

  it "reports a raising cast in any method" do
    source = test %(
      class Question
        private def self.parse_closed_at(json)
          json.dig?("closed").try(&.as_s)
        end
      end
    )
    expect(source.issues.size).to eq(1)
  end

  it "reports each raising cast" do
    source = test %(
      module ModelHelper
        def self.from_json_ld(json)
          {json.as_h, json.as_a, json.as_i, json.as_i64, json.as_f, json.as_f32, json.as_bool, json.as_s}
        end
      end
    )
    expect(source.issues.size).to eq(8)
  end

  it "does not report a nil-returning cast" do
    source = test %(
      module ModelHelper
        def self.from_json_ld(json)
          json.dig?("@id").try(&.as_s?)
        end
      end
    )
    expect(source.issues).to be_empty
  end

  it "does not report a raising cast outside src/models/activity_pub/" do
    source = test %(
      module ModelHelper
        def self.from_json_ld(json)
          json.as_s
        end
      end
    ), "src/models/session.cr"
    expect(source.issues).to be_empty
  end
end
