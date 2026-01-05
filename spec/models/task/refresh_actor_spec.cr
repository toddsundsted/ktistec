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
        to change{actor.reload!.username}
    end

    macro make_subscription(topic, &block)
      before_each do
        spawn do
          {{topic}}.subscribe {{block}}
        rescue
        end
        Fiber.yield
      end
    end

    context "given a subscription" do
      let(notifications) { [0] }

      let(topic) { Ktistec::Topic{"/actor/refresh"} }

      make_subscription(topic) { notifications[0] += 1 }

      it "notifies subscribers" do
        expect do
          subject.perform
          Fiber.yield
        end.to change{notifications[0]}.by(1)
      end

      context "when refresh fails" do
        before_each { actor.assign(iri: "https://remote/returns-404") }

        it "does not notify subscribers" do
          expect do
            subject.perform
            Fiber.yield
          end.not_to change{notifications[0]}
        end
      end
    end

    context "when actor is marked as down" do
      before_each { actor.down! }

      it "marks the actor as up" do
        expect{subject.perform}.to change{actor.reload!.down?}.from(true).to(false)
      end

      context "and refresh fails" do
        let(actor) { super.assign(iri: "https://remote/returns-404") }

        it "does not mark the actor as up" do
          expect{subject.perform}.not_to change{actor.reload!.down?}
        end
      end
    end

    context "when actor is marked as up" do
      before_each { actor.up! }

      context "and refresh fails" do
        let(actor) { super.assign(iri: "https://remote/returns-404") }

        it "marks the actor as down" do
          expect{subject.perform}.to change{actor.reload!.down?}.from(false).to(true)
        end
      end
    end

    it "documents the error if fetch fails" do
      actor.iri = "https://remote/returns-404"
      expect{subject.perform}.
        to change{subject.failures.dup}
    end

    alias Pin = Relationship::Content::Pin

    it "does not create any pins" do
      expect{subject.perform}.not_to change{Pin.count}
    end

    context "given a local actor with a collection of featured posts" do
      let_create(:actor, local: true)

      it "does not fetch the featured collection" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{actor.featured}")
      end
    end

    context "given a remote actor with a collection of featured posts" do
      let_create(:object, named: :object1, attributed_to: actor)
      let_create(:object, named: :object2, attributed_to: actor)
      let_create(:object, named: :object3, attributed_to: actor)

      let(featured_iri) { "https://remote/actors/actor/featured" }

      let(collection) do
        ActivityPub::Collection.new(
          iri: featured_iri,
          items_iris: [object1.iri, object2.iri],
        )
      end

      before_each do
        HTTP::Client.actors << actor.assign(featured: featured_iri)
        HTTP::Client.collections << collection
        HTTP::Client.objects << object1
        HTTP::Client.objects << object2
      end

      it "fetches the featured collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{featured_iri}")
      end

      it "creates pins for featured objects" do
        expect{subject.perform}.to change{Pin.count}.by(2)
        expect(Pin.find?(actor: actor, object: object1)).to be_truthy
        expect(Pin.find?(actor: actor, object: object2)).to be_truthy
      end

      it "does not dereference cached objects" do
        subject.perform
        expect(HTTP::Client.requests).not_to have("GET #{object1.iri}")
        expect(HTTP::Client.requests).not_to have("GET #{object2.iri}")
      end

      context "when objects are not cached" do
        before_each do
          object1.destroy
          object2.destroy
        end

        it "dereferences the objects" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{object1.iri}")
          expect(HTTP::Client.requests).to have("GET #{object2.iri}")
        end

        it "saves the objects" do
          subject.perform
          expect(ActivityPub::Object.find?(iri: object1.iri)).to be_truthy
          expect(ActivityPub::Object.find?(iri: object2.iri)).to be_truthy
        end
      end

      context "when actor already has pins" do
        let_create!(:pin_relationship, named: :pin1, actor: actor, object: object1)
        let_create!(:pin_relationship, named: :pin3, actor: actor, object: object3)

        it "keeps pins still in collection" do
          expect{subject.perform}.not_to change{!!Pin.find?(actor: actor, object: object1)}
        end

        it "removes pins no longer in collection" do
          expect{subject.perform}.to change{!!Pin.find?(actor: actor, object: object3)}.from(true).to(false)
        end

        it "adds new pins in collection" do
          expect{subject.perform}.to change{!!Pin.find?(actor: actor, object: object2)}.from(false).to(true)
        end
      end

      context "when featured collection fetch fails" do
        before_each do
          actor.assign(featured: "https://remote/returns-500").save
          HTTP::Client.actors << actor.assign(username: "changed")
        end

        it "refreshes the actor" do
          expect{subject.perform}.to change{actor.reload!.username}
        end

        it "does not fail" do
          expect{subject.perform}.not_to raise_error
        end
      end

      context "when object dereference fails" do
        before_each do
          object1.destroy
          object1.assign(iri: "https://remote/returns-500").save
          HTTP::Client.objects << object1
        end

        it "skips the failed pin" do
          expect{subject.perform}.not_to change{!!Pin.find?(actor: actor, object: object1)}
        end

        it "creates remaining pins" do
          expect{subject.perform}.to change{!!Pin.find?(actor: actor, object: object2)}.from(false).to(true)
        end
      end

      context "when pin validation fails" do
        let_create(:object, named: :other_object)

        let(collection) do
          ActivityPub::Collection.new(
            iri: featured_iri,
            items_iris: [other_object.iri]
          )
        end

        before_each do
          HTTP::Client.objects << other_object
        end

        it "skips the invalid pin" do
          expect{subject.perform}.not_to change{!!Pin.find?(actor: actor, object: other_object)}
        end

        it "does not fail" do
          expect{subject.perform}.not_to raise_error
        end
      end

      context "with paginated collection" do
        let(first_page) do
          ActivityPub::Collection.new(
            iri: "#{featured_iri}?page=1",
            items_iris: [object1.iri, object2.iri],
            next_iri: "#{featured_iri}?page=2",
          )
        end
        let(last_page) do
          ActivityPub::Collection.new(
            iri: "#{featured_iri}?page=2",
            items_iris: [object3.iri],
            prev_iri: "#{featured_iri}?page=1",
          )
        end
        let(collection) do
          ActivityPub::Collection.new(
            iri: featured_iri,
            first_iri: first_page.iri,
            last_iri: last_page.iri,
          )
        end

        before_each do
          HTTP::Client.collections << collection
          HTTP::Client.collections << first_page
          HTTP::Client.collections << last_page
          HTTP::Client.objects << object3
        end

        it "fetches the featured collection" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{featured_iri}")
        end

        it "traverses all pages" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{featured_iri}?page=1")
          expect(HTTP::Client.requests).to have("GET #{featured_iri}?page=2")
        end

        it "creates pins for featured objects" do
          expect{subject.perform}.to change{Pin.count}.by(3)
          expect(Pin.find?(actor: actor, object: object1)).to be_truthy
          expect(Pin.find?(actor: actor, object: object2)).to be_truthy
          expect(Pin.find?(actor: actor, object: object3)).to be_truthy
        end
      end

      context "with `sync_featured_collection` disabled" do
        let(state) { Task::RefreshActor::State.new(sync_featured_collection: false) }

        before_each { subject.assign(state: state) }

        it "does not fetch the featured collection" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("GET #{actor.featured}")
        end
      end
    end
  end
end
