require "spectator"
require "ameba"

require "../../../src/ameba/ktistec/trailing_comma_on_stacked"

Spectator.describe Ameba::Rule::Ktistec::TrailingCommaOnStacked do
  let(rule) { described_class.new }

  describe "method calls" do
    it "reports when nothing follows a single argument" do
      source = Ameba::Source.new %(
        foo(
          bar
        )
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after a single argument" do
      source = Ameba::Source.new %(
        foo(
          bar,
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last argument" do
      source = Ameba::Source.new %(
        foo(
          bar,
          baz
        )
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last argument" do
      source = Ameba::Source.new %(
        foo(
          bar,
          baz,
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last named argument" do
      source = Ameba::Source.new %(
        foo(
          bar: 1,
          baz: 2
        )
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last named argument" do
      source = Ameba::Source.new %(
        foo(
          bar: 1,
          baz: 2,
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last named argument" do
      source = Ameba::Source.new %(
        foo("a", "b",
          named: value
        )
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last named argument" do
      source = Ameba::Source.new %(
        foo("a", "b",
          named: value,
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last argument" do
      source = Ameba::Source.new %(
        foo(
          bar,
          if baz
            1
          else
            2
          end
        )
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last argument" do
      source = Ameba::Source.new %(
        foo(
          bar,
          if baz
            1
          else
            2
          end,
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "ignores non-parenthesized calls" do
      source = Ameba::Source.new %(
        foo bar,
          baz: 1,
          qux: 2
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "ignores arguments where the last is a heredoc" do
      source = Ameba::Source.new %(
        foo(
          bar,
          baz: <<-KEY
            hello
            KEY
        )
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports redundant comma before closing delimiter" do
      source = Ameba::Source.new %(
        foo(
          bar,
          baz,)
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
      expect(source.issues.first.message).to contain("redundant")
    end
  end

  describe "array literals" do
    it "reports when nothing follows a single element" do
      source = Ameba::Source.new %(
        [
          1
        ]
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after a single element" do
      source = Ameba::Source.new %(
        [
          1,
        ]
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last element" do
      source = Ameba::Source.new %(
        [
          1,
          2
        ]
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last element" do
      source = Ameba::Source.new %(
        [
          1,
          2,
        ]
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports redundant comma before closing delimiter" do
      source = Ameba::Source.new %(
        [
          1,
          2,]
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
      expect(source.issues.first.message).to contain("redundant")
    end

    it "ignores word array literals (%w[])" do
      source = Ameba::Source.new %(
        %w[
          foo
          bar
        ]
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "ignores symbol array literals (%i[])" do
      source = Ameba::Source.new %(
        %i[
          foo
          bar
        ]
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end
  end

  describe "hash literals" do
    it "reports when nothing follows a single entry" do
      source = Ameba::Source.new %(
        {
          "a" => 1
        }
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after a single entry" do
      source = Ameba::Source.new %(
        {
          "a" => 1,
        }
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports when nothing follows the last entry" do
      source = Ameba::Source.new %(
        {
          "a" => 1,
          "b" => 2
        }
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
    end

    it "allows a trailing comma after the last entry" do
      source = Ameba::Source.new %(
        {
          "a" => 1,
          "b" => 2,
        }
      )

      rule.test(source)
      expect(source.issues).to be_empty
    end

    it "reports redundant comma before closing delimiter" do
      source = Ameba::Source.new %(
        {
          "a" => 1,
          "b" => 2,}
      )

      rule.test(source)
      expect(source.issues.size).to eq(1)
      expect(source.issues.first.message).to contain("redundant")
    end
  end
end
