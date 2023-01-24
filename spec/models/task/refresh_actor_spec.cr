require "../../../src/models/task/refresh_actor"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe Task::RefreshActor do
  setup_spec

  let_create(
    :actor, named: :source,
    pem_private_key: <<-KEY
      -----BEGIN PRIVATE KEY-----
      MIIBUwIBADANBgkqhkiG9w0BAQEFAASCAT0wggE5AgEAAkEAwUthNowxsin6I4GS
      6HF7T5KvpzB43yixhf6CHJJ/Atya0xXIxw3JpPbcMls2z5Mss/59uyxDG3kttbmC
      wpovJQIBEQJAZlUVWR0LQDRXP/lNxloyOS+KK1Xlo1HHZQ5E4fM0LrAa857iJLKp
      RFcGJXeCKpSOHjbFhL4EfeRi00r4fO1EnQIhAOd5ux8C/3Faw6bGbDLGKgu2+C/k
      b45JiQ5rgthisuXrAiEA1cYSGwz1wzrkKc/UY4AXosP0LhTkAatAufP+YzsKqy8C
      IQCVxzzX1MNndvcRj3Mv6aK8STcuDEgu5Emf6zaMA6DvHwIgfb/OakPb3EDCcvK5
      K3iGX76PoqLgeXPLuK2kstdvr/0CIQC7ei8o6yboqQgbsVk+Qnf6z1YPaA6hEM7M
      KvkMC2XHAw==
      -----END PRIVATE KEY-----
      KEY
  )
  let_create(:actor)

  let(options) do
    {
      source_iri: source.iri,
      subject_iri: actor.iri
    }
  end

  context "validation" do
    it "rejects missing source" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain_exactly("source")
    end

    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({subject_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.values.flatten).to contain_exactly("missing: missing")
    end

    it "rejects local actor" do
      actor.assign(iri: "https://test.test/actors/actor").save
      new_relationship = described_class.new(**options.merge({subject_iri: actor.iri}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.values.flatten).to contain_exactly("local: #{actor.iri}")
    end

    context "when task already exists for that actor" do
      let!(existing) { described_class.new(**options).save }

      it "rejects task" do
        new_relationship = described_class.new(**options)
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors.values.flatten).to contain_exactly("scheduled: #{actor.iri}")
      end

      it "rejects task if existing task is running" do
        existing.assign(running: true).save
        new_relationship = described_class.new(**options)
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors.values.flatten).to contain_exactly("scheduled: #{actor.iri}")
      end

      it "successfully validates task if existing task is complete" do
        existing.assign(complete: true).save
        new_relationship = described_class.new(**options)
        expect(new_relationship.valid?).to be_true
      end

      it "successfully validates task if existing task has a backtrace" do
        existing.assign(backtrace: ["error"]).save
        new_relationship = described_class.new(**options)
        expect(new_relationship.valid?).to be_true
      end
    end

    it "successfully validates task" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe ".exists?" do
    let!(existing) { described_class.new(**options).save }

    it "returns true if existing task is scheduled" do
      expect(described_class.exists?(actor.iri)).to be_true
    end

    it "returns true if existing task is running" do
      existing.assign(running: true).save
      expect(described_class.exists?(actor.iri)).to be_true
    end

    it "returns false if existing task is complete" do
      existing.assign(complete: true).save
      expect(described_class.exists?(actor.iri)).to be_false
    end

    it "returns false if existing task has a backtrace" do
      existing.assign(backtrace: ["error"]).save
      expect(described_class.exists?(actor.iri)).to be_false
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        source: source,
        actor: actor
      )
    end

    before_each do
      HTTP::Client.actors << actor.assign(username: "foobar")
    end

    it "fetches the actor" do
      subject.perform
      expect(HTTP::Client.requests).to have("GET #{actor.iri}")
    end

    it "updates the actor" do
      expect{subject.perform}.
        to change{ActivityPub::Actor.find(actor.iri).username}
    end

    it "documents the error if fetch fails" do
      actor.iri = "https://remote/returns-404"
      expect{subject.perform}.
        to change{subject.failures.dup}
    end
  end
end
