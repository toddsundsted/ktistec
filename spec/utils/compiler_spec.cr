require "../../src/utils/compiler"

require "../spec_helper/base"

module CompilerSpec
  class Foo < School::Fact end
  class Bar < School::Property(String) end
  class Baz < School::Relationship(String, String) end

  class FooBar < School::Pattern
    getter target : School::Expression?
    getter options : Hash(String, School::Expression)

    def initialize(@target = nil, @options = Hash(String, School::Expression).new)
    end

    def vars : Enumerable(String)
      raise "not implemented"
    end

    def match(bindings : School::Bindings, trace : School::Trace? = nil, &block : School::Bindings -> Nil) : Nil
      raise "not implemented"
    end

    record Call,
      name : String,
      target : School::DomainTypes? = nil,
      options : Hash(String, School::DomainTypes) = Hash(String, School::DomainTypes).new

    class_getter calls = [] of Call

    def self.assert(target, options)
      @@calls = @@calls.dup << Call.new("assert", target, options)
    end

    def self.retract(target, options)
      @@calls = @@calls.dup << Call.new("retract", target, options)
    end
  end
end

Ktistec::Compiler.register_constant(CompilerSpec::Foo)
Ktistec::Compiler.register_constant(CompilerSpec::Bar)
Ktistec::Compiler.register_constant(CompilerSpec::Baz)
Ktistec::Compiler.register_constant(CompilerSpec::FooBar)
Ktistec::Compiler.register_accessor(size)
Ktistec::Compiler.register_accessor(abs)

Spectator.describe Ktistec::Compiler do
  describe "#compile" do
    it "returns a domain" do
      compiler = described_class.new("")
      expect(compiler.compile).to be_a(School::Domain)
    end

    it "compiles rule definitions" do
      domain = described_class.new(%q|rule "one" end rule "two" end|).compile
      expect(domain.rules.map(&.class)).to eq([School::Rule, School::Rule])
    end

    subject { described_class.new(input) }

    context "given an input" do
      let(input) do
        <<-END
          rule "name"
            condition FooBar, "foo bar", foo: 12345
            condition FooBar, foo_bar, foo: bar
            condition FooBar, not "foo bar", foo: not 12345
            condition FooBar, not foo_bar, foo: not bar
            condition FooBar, foo.size, foo: bar.abs
            assert FooBar, "foo_bar", foo: 12345
            retract FooBar, foo_bar, foo: bar
          end
        END
      end

      context "the compiled domain" do
        let(domain) { subject.compile }

        it "defines one rule" do
          expect(domain.rules.size).to eq(1)
        end

        context "with rule" do
          let(rule) { domain.rules.first }

          it "has the specified name" do
            expect(rule.name).to eq("name")
          end

          it "defines conditions" do
            expect(rule.conditions.size).to eq(5)
          end

          context "with conditions" do
            let(conditions) { rule.conditions.map(&.as(CompilerSpec::FooBar)) }

            # arguments

            it "is a literal" do
              expect(conditions[0].target).to eq(School::Lit.new("foo bar"))
            end

            it "is a variable" do
              expect(conditions[1].target).to eq(School::Var.new("foo_bar"))
            end

            it "handles not" do
              expect(conditions[2].target).to eq(School::Not.new(School::Lit.new("foo bar")))
            end

            it "handles not" do
              expect(conditions[3].target).to eq(School::Not.new(School::Var.new("foo_bar")))
            end

            context "with accessor" do
              let(accessor) { conditions[4].target.as(School::Accessor) }

              it "invokes accessor" do
                bindings = School::Bindings{"foo" => "1234567890"}
                expect(accessor.call(bindings)).to eq(10)
              end

              it "raises an error if receiver doesn't respond to accessor" do
                bindings = School::Bindings{"foo" => 1234567890}
                expect{accessor.call(bindings)}.to raise_error(Ktistec::Compiler::LinkError, /invalid accessor/)
              end

              it "raises an error if receiver is unbound" do
                bindings = School::Bindings.new
                expect{accessor.call(bindings)}.to raise_error(Ktistec::Compiler::LinkError, /unbound receiver/)
              end
            end

            # options

            it "is a literal" do
              expect(conditions[0].options).to eq({"foo" => School::Lit.new(12345)})
            end

            it "is a variable" do
              expect(conditions[1].options).to eq({"foo" => School::Var.new("bar")})
            end

            it "handles not" do
              expect(conditions[2].options).to eq({"foo" => School::Not.new(School::Lit.new(12345))})
            end

            it "handles not" do
              expect(conditions[3].options).to eq({"foo" => School::Not.new(School::Var.new("bar"))})
            end

            context "with accessor" do
              let(accessor) { conditions[4].options["foo"].as(School::Accessor) }

              it "invokes accessor" do
                bindings = School::Bindings{"bar" => -1234567890}
                expect(accessor.call(bindings)).to eq(1234567890)
              end

              it "raises an error if receiver doesn't respond to accessor" do
                bindings = School::Bindings{"bar" => "1234567890"}
                expect{accessor.call(bindings)}.to raise_error(Ktistec::Compiler::LinkError, /invalid accessor/)
              end

              it "raises an error if receiver is unbound" do
                bindings = School::Bindings.new
                expect{accessor.call(bindings)}.to raise_error(Ktistec::Compiler::LinkError, /unbound receiver/)
              end
            end
          end

          it "defines actions" do
            expect(rule.actions.size).to eq(2)
          end

          context "with actions" do
            let(actions) { rule.actions }

            before_each { CompilerSpec::FooBar.calls.clear }

            let(bindings) { School::Bindings{"foo" => "bar", "bar" => "foo", "foo_bar" => "foo_bar"} }

            it "invokes assert method" do
              target = "foo_bar"
              options = Hash(String, School::DomainTypes).new.merge({"foo" => 12345})
              expect{actions[0].call(rule, bindings)}.to change{CompilerSpec::FooBar.calls}.to([CompilerSpec::FooBar::Call.new("assert", target, options)])
            end

            it "invokes retract method" do
              target = "foo_bar"
              options = Hash(String, School::DomainTypes).new.merge({"foo" => "foo"})
              expect{actions[1].call(rule, bindings)}.to change{CompilerSpec::FooBar.calls}.to([CompilerSpec::FooBar::Call.new("retract", target, options)])
            end
          end
        end
      end
    end

    context "given a rule definition using any" do
      let(input) { %q|rule "name" any FooBar end| }

      it "defines conditions" do
        expect(subject.compile.rules.first.conditions.size).to eq(1)
      end

      it "is Any" do
        expect(subject.compile.rules.first.conditions.first).to be_a(School::Pattern::Any)
      end
    end

    context "given a rule definition using none" do
      let(input) { %q|rule "name" none FooBar end| }

      it "defines conditions" do
        expect(subject.compile.rules.first.conditions.size).to eq(1)
      end

      it "is None" do
        expect(subject.compile.rules.first.conditions.first).to be_a(School::Pattern::None)
      end
    end

    context "given a rule definition using a fact" do
      let(input) { %q|rule "name" condition Foo end| }

      it "defines conditions" do
        expect(subject.compile.rules.first.conditions.size).to eq(1)
      end

      it "is a nullary pattern" do
        expect(subject.compile.rules.first.conditions.first).to be_a(School::NullaryPattern(CompilerSpec::Foo))
      end
    end

    context "given a fact" do
      let(fact) { CompilerSpec::Foo.new }

      let(empty_set) { Set(School::Fact).new }

      let(bindings) { School::Bindings.new }

      before_each { School::Fact.clear! }

      context "and a rule definition asserting a fact" do
        let(input) { %q|rule "name" assert Foo end| }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "asserts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(Set{fact})
        end
      end

      context "and a rule definition retracting a fact" do
        let(input) { %q|rule "name" retract Foo end| }

        before_each { School::Fact.assert(fact) }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "retracts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(empty_set)
        end
      end
    end

    context "given a rule definition using a property fact" do
      let(input) { %q|rule "name" condition Bar, abc end| }

      it "defines conditions" do
        expect(subject.compile.rules.first.conditions.size).to eq(1)
      end

      it "is a unary pattern" do
        expect(subject.compile.rules.first.conditions.first).to be_a(School::UnaryPattern(CompilerSpec::Bar, School::Expression))
      end
    end

    context "given a fact" do
      let(fact) { CompilerSpec::Bar.new("abc") }

      let(empty_set) { Set(School::Fact).new }

      let(bindings) { School::Bindings.new }

      before_each { School::Fact.clear! }

      context "and a rule definition asserting a property fact" do
        let(input) { %q|rule "name" assert Bar, "abc" end| }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "asserts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(Set{fact})
        end
      end

      context "and a rule definition retracting a property fact" do
        let(input) { %q|rule "name" retract Bar, "abc" end| }

        before_each { School::Fact.assert(fact) }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "retracts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(empty_set)
        end
      end
    end

    context "given a rule definition using a relationship fact" do
      let(input) { %q|rule "name" condition Baz, one, two end| }

      it "defines conditions" do
        expect(subject.compile.rules.first.conditions.size).to eq(1)
      end

      it "is a binary pattern" do
        expect(subject.compile.rules.first.conditions.first).to be_a(School::BinaryPattern(CompilerSpec::Baz, School::Expression, School::Expression))
      end
    end

    context "given a fact" do
      let(fact) { CompilerSpec::Baz.new("one", "two") }

      let(empty_set) { Set(School::Fact).new }

      let(bindings) { School::Bindings.new }

      before_each { School::Fact.clear! }

      context "and a rule definition asserting a relationship fact" do
        let(input) { %q|rule "name" assert Baz, "one", "two" end| }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "asserts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(Set{fact})
        end
      end

      context "and a rule definition retracting a relationship fact" do
        let(input) { %q|rule "name" retract Baz, "one", "two" end| }

        before_each { School::Fact.assert(fact) }

        it "defines actions" do
          expect(subject.compile.rules.first.actions.size).to eq(1)
        end

        it "retracts a fact" do
          rule = subject.compile.rules.first
          expect{rule.actions.first.call(rule, bindings)}.to change{School::Fact.facts}.to(empty_set)
        end
      end
    end

    it "raises an error if constant is undefined" do
      input = %q|rule "name" condition UnknownClass end|
      expect{described_class.new(input).compile}.to raise_error(Ktistec::Compiler::LinkError, /undefined constant/)
    end

    it "raises an error if there are too many arguments" do
      input = %q|rule "name" condition FooBar, foo, bar end|
      expect{described_class.new(input).compile}.to raise_error(Ktistec::Compiler::LinkError, /too many arguments/)
    end

    it "raises an error if accessor is undefined" do
      input = %q|rule "name" condition FooBar, zip.zap end|
      expect{described_class.new(input).compile}.to raise_error(Ktistec::Compiler::LinkError, /undefined accessor/)
    end
  end
end
