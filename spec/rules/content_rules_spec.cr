require "../../src/rules/content_rules"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ContentRules do
  setup_spec

  {% if flag?(:"school:metrics") %}
    before_all do
      School::Metrics.reset
    end
    after_all do
      metrics = School::Metrics.metrics
      puts
      puts "runs:            #{metrics[:runs]}"
      puts "rules:           #{metrics[:rules]}"
      puts "conditions:      #{metrics[:conditions]}"
      puts "conditions/run:  #{metrics[:conditions_per_run]}"
      puts "conditions/rule: #{metrics[:conditions_per_rule]}"
      puts "operations:      #{metrics[:operations]}"
      puts "operations/run:  #{metrics[:operations_per_run]}"
      puts "operations/rule: #{metrics[:operations_per_rule]}"
      puts "runtime:         #{metrics[:runtime]}"
    end
  {% end %}

  describe ".new" do
    it "creates an instance" do
      expect(described_class.new).to be_a(ContentRules)
    end
  end
end
