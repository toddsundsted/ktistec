require "../../src/framework/observable"

require "../spec_helper/base"

private class SyntheticObservable
  OBSERVERS = Ktistec::Observable::Registry(SyntheticObservable).new

  getter log = [] of String

  def fire
    SyntheticObservable::OBSERVERS.notify(:event, self)
  end
end

private class SyntheticSubclass < SyntheticObservable
  OBSERVERS = Ktistec::Observable::Registry(SyntheticSubclass).new

  def fire
    SyntheticSubclass::OBSERVERS.notify(:event, self)
    super
  end
end

private class SyntheticDeepSubclass < SyntheticSubclass
  OBSERVERS = Ktistec::Observable::Registry(SyntheticDeepSubclass).new

  def fire
    SyntheticDeepSubclass::OBSERVERS.notify(:event, self)
    super
  end
end

private class SyntheticSuppressingSubclass < SyntheticObservable
  OBSERVERS = Ktistec::Observable::Registry(SyntheticSuppressingSubclass).new

  def fire
    SyntheticSuppressingSubclass::OBSERVERS.notify(:event, self)
    # deliberately no `super`. suppresses the base observer
  end
end

Spectator.describe Ktistec::Observable::Registry do
  describe "#observe / #notify" do
    let(registry) { Ktistec::Observable::Registry(SyntheticObservable).new }

    it "is a no-op" do
      expect { registry.notify(:none, SyntheticObservable.new) }.not_to raise_error
    end

    it "invokes a registered observer" do
      seen = [] of SyntheticObservable
      registry.observe(:event) { |instance| seen << instance }
      base = SyntheticObservable.new
      registry.notify(:event, base)
      expect(seen).to eq([base])
    end

    it "invokes observers in registration order" do
      order = [] of Int32
      registry.observe(:event) { order << 1 }
      registry.observe(:event) { order << 2 }
      registry.notify(:event, SyntheticObservable.new)
      expect(order).to eq([1, 2])
    end

    it "distinguishes events" do
      seen = [] of Symbol
      registry.observe(:a) { seen << :a }
      registry.observe(:b) { seen << :b }
      registry.notify(:a, SyntheticObservable.new)
      expect(seen).to eq([:a])
    end
  end

  describe "#clear" do
    let(registry) { Ktistec::Observable::Registry(SyntheticObservable).new }

    it "removes registered observers" do
      seen = [] of Symbol
      registry.observe(:event) { seen << :fired }
      registry.clear
      registry.notify(:event, SyntheticObservable.new)
      expect(seen).to be_empty
    end
  end

  describe "composition across a hierarchy" do
    before_each do
      SyntheticObservable::OBSERVERS.observe(:event) { |instance| instance.log << "base" }
      SyntheticSubclass::OBSERVERS.observe(:event) { |instance| instance.log << "middle" }
      SyntheticDeepSubclass::OBSERVERS.observe(:event) { |instance| instance.log << "leaf" }
      SyntheticSuppressingSubclass::OBSERVERS.observe(:event) { |instance| instance.log << "suppressed" }
    end

    after_each do
      SyntheticObservable::OBSERVERS.clear
      SyntheticSubclass::OBSERVERS.clear
      SyntheticDeepSubclass::OBSERVERS.clear
      SyntheticSuppressingSubclass::OBSERVERS.clear
    end

    it "fires only the base observer" do
      base = SyntheticObservable.new
      base.fire
      expect(base.log).to eq(["base"])
    end

    it "fires the subclass observer then the base" do
      middle = SyntheticSubclass.new
      middle.fire
      expect(middle.log).to eq(["middle", "base"])
    end

    it "fires every observer" do
      leaf = SyntheticDeepSubclass.new
      leaf.fire
      expect(leaf.log).to eq(["leaf", "middle", "base"])
    end

    it "suppresses inherited observers" do
      suppressed = SyntheticSuppressingSubclass.new
      suppressed.fire
      expect(suppressed.log).to eq(["suppressed"])
    end
  end
end
