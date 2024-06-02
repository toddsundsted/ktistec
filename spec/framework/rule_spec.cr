require "../../src/framework/rule"

require "../spec_helper/base"

class RuleModel
  include Ktistec::Model(Nil)

  @[Persistent]
  property parent_id : Int64?
  belongs_to child_of, class_name: RuleModel, foreign_key: parent_id, primary_key: id

  @[Persistent]
  property name : String?
  derived quux : String?, aliased_to: name
end

Spectator.describe Ktistec::Rule do
  describe ".make_pattern" do
    Ktistec::Rule.make_pattern(
      RulePattern,
      RuleModel
    )

    it "inherits from School::Pattern" do
      expect(RulePattern < School::Pattern).to be_true
    end
  end

  context "given a pattern class" do
    Ktistec::Rule.make_pattern(
      RulePattern,
      RuleModel,
      associations: [child_of],
      properties: [id, name, quux]
    )

    describe "#vars" do
      it "returns the vars" do
        expect(RulePattern.new.vars).to be_empty
      end

      it "returns the vars" do
        expect(RulePattern.new(School::Lit.new("lit")).vars).to be_empty
      end

      it "returns the vars" do
        expect(RulePattern.new(School::Var.new("var")).vars).to eq(["var"])
      end

      it "returns the vars" do
        expect(RulePattern.new(id: School::Lit.new("lit")).vars).to be_empty
      end

      it "returns the vars" do
        expect(RulePattern.new(id: School::Var.new("var")).vars).to eq(["var"])
      end
    end

    context "and a database and models" do
      before_each do
        Ktistec.database.exec <<-SQL
          CREATE TABLE IF NOT EXISTS rule_models (
            id integer PRIMARY KEY AUTOINCREMENT,
            parent_id integer,
            name text
          )
        SQL
        Ktistec.database.exec <<-SQL
          INSERT INTO rule_models (id, parent_id, name)
          VALUES (1, null, "one"), (2, 1, "two"), (3, 2, "three")
        SQL
      end
      after_each do
        Ktistec.database.exec "DROP TABLE IF EXISTS rule_models"
      end

      let(model1) { RuleModel.find(1) }
      let(model2) { RuleModel.find(2) }
      let(model3) { RuleModel.find(3) }
      let(model9999) { RuleModel.new(id: 9999_i64) }
      let(model_nil) { RuleModel.new(id: nil) }

      let(yields) { [] of School::Bindings }

      let(block) { ->(bindings : School::Bindings){ yields << bindings } }

      let(bindings) { School::Bindings.new }

      let(empty) { School::Bindings.new }

      describe "#match" do
        context "with no arguments" do
          subject { RulePattern.new }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(3)
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty, empty, empty])
          end
        end

        context "with an undefined argument" do
          subject { RulePattern.new(foo: School::Var.new("foo")) }

          it "raises an error" do
            expect{subject.match(bindings, &block)}.to raise_error(ArgumentError)
          end
        end

        # target

        context "with a lit target that matches a model" do
          subject { RulePattern.new(School::Lit.new(model1)) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty])
          end
        end

        context "with a lit target that does not match a model" do
          subject { RulePattern.new(School::Lit.new(model9999)) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a lit target that does not match a model" do
          subject { RulePattern.new(School::Lit.new(model_nil)) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with an unbound var target" do
          subject { RulePattern.new(School::Var.new("target")) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(3)
          end

          it "binds the target to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"target" => model1}, {"target" => model2}, {"target" => model3}])
          end
        end

        context "with a bound var target that matches a model" do
          let(bindings) { School::Bindings{"target" => model1} }

          subject { RulePattern.new(School::Var.new("target")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the target to the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"target" => model1}])
          end
        end

        context "with a bound var target that does not match a model" do
          let(bindings) { School::Bindings{"target" => model9999} }

          subject { RulePattern.new(School::Var.new("target")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a bound var target that does not match a model" do
          let(bindings) { School::Bindings{"target" => model_nil} }

          subject { RulePattern.new(School::Var.new("target")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a not target" do
          subject { RulePattern.new(School::Not.new(School::Lit.new(model1), name: "target")) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the target to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"target" => model2}, {"target" => model3}])
          end
        end

        context "with a not target" do
          subject { RulePattern.new(School::Not.new(School::Lit.new(model_nil))) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(3)
          end

          it "binds the target to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty, empty, empty])
          end
        end

        context "with a within target" do
          subject { RulePattern.new(School::Within.new(School::Lit.new(model1), School::Lit.new(model3), name: "target")) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the target to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"target" => model1}, {"target" => model3}])
          end
        end

        context "with a within target" do
          subject { RulePattern.new(School::Within.new(School::Lit.new(model_nil))) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        # associations

        context "with a lit association that matches a model" do
          subject { RulePattern.new(child_of: School::Lit.new(model1)) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty])
          end
        end

        context "with a lit association that does not match a model" do
          subject { RulePattern.new(child_of: School::Lit.new(model9999)) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with an unbound var association" do
          subject { RulePattern.new(child_of: School::Var.new("parent")) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the association to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"parent" => model1}, {"parent" => model2}])
          end
        end

        context "with a bound var association that matches a model" do
          let(bindings) { School::Bindings{"parent" => model1} }

          subject { RulePattern.new(child_of: School::Var.new("parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"parent" => model1}])
          end
        end

        context "with a bound var association that does not match a model" do
          let(bindings) { School::Bindings{"parent" => model9999} }

          subject { RulePattern.new(child_of: School::Var.new("parent")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        # context on the following two sets of tests: the semantics of
        # a not expression are the same as the `!=` operator in SQL.
        # in particular, "xyz != 123" is *not* true if column "xyz" is
        # `null` because a null column is treated as having no value
        # to compare against.

        context "with a not association" do
          subject { RulePattern.new(child_of: School::Not.new(School::Lit.new(model1), name: "parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"parent" => model2}])
          end
        end

        context "with a not association" do
          let(bindings) { School::Bindings{"model" => model1} }

          subject { RulePattern.new(child_of: School::Not.new(School::Var.new("model"), name: "parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"model" => model1, "parent" => model2}])
          end
        end

        context "with a within association" do
          subject { RulePattern.new(child_of: School::Within.new(School::Lit.new(model2), name: "parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"parent" => model2}])
          end
        end

        context "with a within association" do
          let(bindings) { School::Bindings{"model" => model2} }

          subject { RulePattern.new(child_of: School::Within.new(School::Var.new("model"), name: "parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"model" => model2, "parent" => model2}])
          end
        end

        # properties

        context "with a lit property that matches a model value" do
          subject { RulePattern.new(id: School::Lit.new(1_i64)) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty])
          end
        end

        context "with a lit property that matches a model value through accessor" do
          subject { RulePattern.new(id: School::Lit.new(model1).id) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to eq([empty])
          end
        end

        context "with a lit property that does not match a model value" do
          subject { RulePattern.new(id: School::Lit.new(model9999).id) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a lit property that does not match a model value" do
          subject { RulePattern.new(id: School::Lit.new(model_nil).id) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with an unbound var property" do
          subject { RulePattern.new(id: School::Var.new("id")) }

          it "invokes the block once for each match" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(3)
          end

          it "binds the property value to each match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"id" => 1_i64}, {"id" => 2_i64}, {"id" => 3_i64}])
          end
        end

        context "with a bound var property that matches a model value" do
          let(bindings) { School::Bindings{"id" => 1_i64} }

          subject { RulePattern.new(id: School::Var.new("id")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"id" => 1_i64}])
          end
        end

        context "with a bound var property that does not match a model value" do
          let(bindings) { School::Bindings{"id" => 9999_i64} }

          subject { RulePattern.new(id: School::Var.new("id")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a bound var property that does not match a model value" do
          let(bindings) { School::Bindings{"id" => nil} }

          subject { RulePattern.new(id: School::Var.new("id")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a not property" do
          subject { RulePattern.new(id: School::Not.new(School::Lit.new(1_i64), name: "id")) }

          it "invokes the block twice" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"id" => 2_i64}, {"id" => 3_i64}])
          end
        end

        context "with a not property" do
          let(bindings) { School::Bindings{"value" => 1_i64} }

          subject { RulePattern.new(id: School::Not.new(School::Var.new("value"), name: "id")) }

          it "invokes the block twice" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"value" => 1_i64, "id" => 2_i64}, {"value" => 1_i64, "id" => 3_i64}])
          end
        end

        context "with a within property" do
          subject { RulePattern.new(id: School::Within.new(School::Lit.new(2_i64), School::Lit.new(3_i64), name: "id")) }

          it "invokes the block twice" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"id" => 2_i64}, {"id" => 3_i64}])
          end
        end

        context "with a within property" do
          let(bindings) { School::Bindings{"value" => 2_i64} }

          subject { RulePattern.new(id: School::Within.new(School::Var.new("value"), School::Lit.new(3_i64), name: "id")) }

          it "invokes the block twice" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(2)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"value" => 2_i64, "id" => 2_i64}, {"value" => 2_i64, "id" => 3_i64}])
          end
        end

        context "with a property and the function 'strip'" do
          subject { RulePattern.new(name: Ktistec::Function::Strip.new(School::Lit.new("<span>th</span><span>ree</span>"), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        context "with a property and the function 'strip'" do
          let(bindings) { School::Bindings{"value" => "<span>th</span><span>ree</span>"} }

          subject { RulePattern.new(name: Ktistec::Function::Strip.new(School::Var.new("value"), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"value" => "<span>th</span><span>ree</span>", "name" => "three"}])
          end
        end

        context "with a property and the function 'strip'" do
          subject { RulePattern.new(name: Ktistec::Function::Strip.new(School::Accessor.new { "<span>th</span><span>ree</span>" }, name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        context "with a property and the predicate 'filter'" do
          subject { RulePattern.new(name: Ktistec::Function::Filter.new(School::Lit.new("three"), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        context "with a property and the predicate 'filter'" do
          let(bindings) { School::Bindings{"value" => "three"} }

          subject { RulePattern.new(name: Ktistec::Function::Filter.new(School::Var.new("value"), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"value" => "three", "name" => "three"}])
          end
        end

        context "with a property and the predicate 'filter'" do
          subject { RulePattern.new(name: Ktistec::Function::Filter.new(School::Accessor.new { "three" }, name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        context "with a property, the predicate 'filter', and the function 'strip'" do
          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Lit.new("<span>THREE</span>")), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        context "with a property, the predicate 'filter', and the function 'strip'" do
          let(bindings) { School::Bindings{"value" => "<span>THREE</span>"} }

          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Var.new("value")), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"value" => "<span>THREE</span>", "name" => "three"}])
          end
        end

        context "with a property, the predicate 'filter', and the function 'strip'" do
          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Accessor.new { "<span>THREE</span>" }), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "three"}])
          end
        end

        # wildcards

        context "with a wildcard" do
          before_each { RuleModel.new(name: "%four%").save }

          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Lit.new("<p>three four five</p>")), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "%four%"}])
          end
        end

        context "with an escaped wildcard" do
          before_each { RuleModel.new(name: %q|\%|).save }

          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Lit.new("%")), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => %q|\%|}])
          end
        end

        context "with an escaped escape" do
          before_each { RuleModel.new(name: %q|\\|).save }

          subject { RulePattern.new(name: Ktistec::Function::Filter.new(Ktistec::Function::Strip.new(School::Lit.new("\\")), name: "name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => %q|\\|}])
          end
        end

        # derived properties

        context "via a derived property" do
          before_each { RuleModel.new(name: "test").save }

          subject { RulePattern.new(quux: School::Lit.new("test", name: "quux")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the match" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"quux" => "test"}])
          end
        end

        # edge cases

        context "with a target with a cached association" do
          let(model11) { RuleModel.new(id: 11_i64, parent_id: 2_i64).save }

          pre_condition { expect(model11.child_of?).to eq(model2) }

          subject { RulePattern.new(School::Lit.new(model11), child_of: School::Var.new("parent")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the association" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"parent" => model2}])
          end
        end

        context "with a target with an uncached association" do
          let(model11) { RuleModel.new(id: 11_i64, parent_id: 22_i64).save }

          pre_condition { expect(model11.child_of?).to be_nil }

          subject { RulePattern.new(School::Lit.new(model11), child_of: School::Var.new("parent")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end

        context "with a target with a non-nil property" do
          let(model11) { RuleModel.new(id: 11_i64, name: "eleven").save }

          pre_condition { expect(model11.name).to eq("eleven") }

          subject { RulePattern.new(School::Lit.new(model11), name: School::Var.new("name")) }

          it "invokes the block once" do
            expect{subject.match(bindings, &block)}.to change{yields.size}.by(1)
          end

          it "binds the association" do
            subject.match(bindings, &block)
            expect(yields).to eq([{"name" => "eleven"}])
          end
        end

        context "with a target with a nil property" do
          let(model11) { RuleModel.new(id: 11_i64).save }

          pre_condition { expect(model11.name).to be_nil }

          subject { RulePattern.new(School::Lit.new(model11), name: School::Var.new("name")) }

          it "does not invoke the block" do
            expect{subject.match(bindings, &block)}.not_to change{yields.size}
          end

          it "does not bind values" do
            subject.match(bindings, &block)
            expect(yields).to be_empty
          end
        end
      end

      describe ".assert" do
        let(bindings) { School::Bindings{"id" => 9999_i64} }

        it "creates an instance" do
          expect{RulePattern.assert(nil, id: 9999_i64)}.to change{RuleModel.count(id: 9999_i64)}.by(1)
        end

        it "creates an instance" do
          expect{RulePattern.assert(nil, {"id" => 9999_i64})}.to change{RuleModel.count(id: 9999_i64)}.by(1)
        end
      end

      describe ".retract" do
        let(bindings) { School::Bindings{"id" => 1_i64} }

        it "destroys an instance" do
          expect{RulePattern.retract(nil, id: 1_i64)}.to change{RuleModel.count(id: 1_i64)}.by(-1)
        end

        it "destroys an instance" do
          expect{RulePattern.retract(nil, {"id" => 1_i64})}.to change{RuleModel.count(id: 1_i64)}.by(-1)
        end
      end
    end
  end
end
