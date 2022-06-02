require "../../src/framework/rule"

require "../spec_helper/model"

class RuleModel
  include Ktistec::Model(Nil)
  include School::DomainType

  @[Persistent]
  property parent_id : Int64?
  belongs_to child_of, class_name: RuleModel, foreign_key: parent_id, primary_key: id
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
      properties: [id]
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
          CREATE TABLE rule_models (
            id integer PRIMARY KEY AUTOINCREMENT,
            parent_id integer
          )
        SQL
        Ktistec.database.exec <<-SQL
          INSERT INTO rule_models (id, parent_id)
          VALUES (1, null), (2, 1), (3, 2)
        SQL
      end
      after_each do
        Ktistec.database.exec "DROP TABLE rule_models"
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
