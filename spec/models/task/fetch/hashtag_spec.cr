require "../../../../src/models/task/fetch/hashtag"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/network"

Spectator.describe Task::Fetch::Hashtag do
  setup_spec

  let_create(:actor, named: :source, with_keys: true)

  let(options) do
    {
      source_iri: source.iri,
      subject_iri: random_string
    }
  end

  context "validation" do
    it "rejects missing source" do
      new_task = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain_exactly("source")
    end

    it "rejects blank name" do
      new_task = described_class.new(**options.merge({subject_iri: ""}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain("name")
    end

    it "successfully validates instance" do
      new_task = described_class.new(**options)
      expect(new_task.valid?).to be_true
    end
  end

  describe "#follow?" do
    subject { described_class.new(**options).save }

    it "returns false" do
      expect(subject.follow?).to be_false
    end

    context "given a follow relationship" do
      let_create!(:follow_hashtag_relationship, actor: source, name: options[:subject_iri])

      it "returns true" do
        expect(subject.follow?).to be_true
      end
    end
  end

  describe "#perform" do
    # these tests assume this is a "followed" hashtag
    let_create!(:follow_hashtag_relationship, named: nil, actor: source, name: "hashtag")

    subject do
      described_class.new(source: source, name: "hashtag").save
    end

    it "sets the next attempt at" do
      subject.perform
      expect(subject.next_attempt_at).not_to be_nil
    end

    def horizon(task)
      task.state.nodes.map(&.href)
    end

    context "given no tagged object" do
      it "has an empty horizon" do
        expect(horizon(subject)).to be_empty
      end
    end

    macro let_build_object(index, *tags)
      let_build(
        :object,
        named: object{{index}},
        hashtags: [
          {% for tag in tags %}
            Factory.build(
              :hashtag,
              created_at: Time.utc,
              name: {{tag.split("/").last}},
              href: {{tag}}
            ),
          {% end %}
        ]
      )
    end

    context "given one tagged object" do
      let_build_object(1, "https://remote/tags/hashtag") # remote collection
      let_build(:collection, named: :hashtag, iri: "https://remote/tags/hashtag")

      before_each do
        # the object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.collections << hashtag.assign(items_iris: [object1.iri])
      end

      let(node) { subject.state.nodes.first }

      it "starts with the collection in the horizon" do
        expect(horizon(subject)).to contain_exactly("https://remote/tags/hashtag")
      end

      it "fetches the hashtag collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{hashtag.iri}")
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "does not change time of last success" do
        expect{subject.perform}.not_to change{node.last_success_at}
      end
    end

    context "given one tagged object" do
      let_build_object(1, "https://test.test/tags/hashtag") # local collection
      let_build(:collection, named: :hashtag, iri: "https://test.test/tags/hashtag")

      before_each do
        # the object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.collections << hashtag.assign(items_iris: [object1.iri])
      end

      let(node) { subject.state.nodes.first }

      it "starts with the href of the hashtag in the horizon" do
        expect(horizon(subject)).to contain_exactly("https://test.test/tags/hashtag")
      end

      it "does not fetch the hashtag collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).not_to have("GET https://test.test/tags/hashtag")
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "does not change time of last success" do
        expect{subject.perform}.not_to change{node.last_success_at}
      end
    end

    def find?(iri)
      case iri
      when /objects/
        ActivityPub::Object.find?(iri)
      when /actors/
        ActivityPub::Actor.find?(iri)
      else
        raise "unsupported"
      end
    end

    context "given many tagged objects" do
      let_build_object(1, "https://remote/tags/hashtag")
      let_build_object(2, "https://remote/tags/hashtag")
      let_build_object(3, "https://remote/tags/hashtag")
      let_build(:collection, named: :hashtag, iri: "https://remote/tags/hashtag")

      before_each do
        # only the first object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.objects << object2
        HTTP::Client.objects << object3
        HTTP::Client.actors << object1.attributed_to
        HTTP::Client.actors << object2.attributed_to
        HTTP::Client.actors << object3.attributed_to
        HTTP::Client.collections << hashtag.assign(items_iris: [object1.iri, object2.iri, object3.iri])
      end

      let(node) { subject.state.nodes.first }

      it "fetches the hashtag collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{hashtag.iri}")
      end

      it "fetches an object from the collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{object2.iri}")
      end

      it "persists an object from the collection" do
        expect{subject.perform(1)}.to change{find?(object2.iri)}
      end

      it "changes time of last attempt" do
        expect{subject.perform(1)}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform(1)}.to change{node.last_success_at}
      end

      it "sets the next attempt in the immediate future" do
        subject.perform(1)
        expect(subject.next_attempt_at.not_nil!).to be < 1.minute.from_now
      end

      it "fetches the hashtag collection once" do
        subject.perform
        expect(HTTP::Client.requests.count { |request| request === "GET #{hashtag.iri}"}).to eq(1)
      end

      it "fetches all the objects from the collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{object2.iri}", "GET #{object3.iri}")
      end

      it "persists all the objects from the collection" do
        expect{subject.perform}.to change{ {find?(object2.iri), find?(object3.iri)}.any?(Nil) }.to(false)
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
      end

      context "with all objects already fetched" do
        before_each { subject.perform }

        it "sets the next attempt in the far future" do
          subject.perform
          expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
        end

        # the following tests check to ensure prior behavior that was
        # reverted is not reintroduced.  we _do not_ want to check
        # collections more than once during a run, to avoid spamming
        # other sites.

        context "and a later object" do
          # an uncached object
          let_build_object(4, "https://remote/tags/hashtag")

          before_each do
            HTTP::Client.objects << object4
            HTTP::Client.actors << object4.attributed_to
            HTTP::Client.collections << hashtag.assign(items_iris: [object1.iri, object2.iri, object3.iri, object4.iri])
          end

          it "does not fetch the object" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{object4.iri}")
          end

          it "sets the next attempt in the far future" do
            subject.perform
            expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
          end
        end

        context "and a later object" do
          # an object, but dereferenced and cached via some other process
          let_build_object(4, "https://remote/tags/hashtag")

          before_each do
            HTTP::Client.objects << object4.save
            HTTP::Client.actors << object4.attributed_to
            HTTP::Client.collections << hashtag.assign(items_iris: [object1.iri, object2.iri, object3.iri, object4.iri])
          end

          it "does not fetch the object" do
            subject.perform
            expect(HTTP::Client.requests).not_to have("GET #{object4.iri}")
          end

          it "sets the next attempt in the far future" do
            subject.perform
            expect(subject.next_attempt_at.not_nil!).to be_between(170.minutes.from_now, 310.minutes.from_now)
          end
        end

        context "and later objects" do
          # objects in a new collection
          let_build_object(4, "https://other/tags/hashtag")
          let_build_object(5, "https://other/tags/hashtag")
          let_build(:collection, named: :other, iri: "https://other/tags/hashtag")

          before_each do
            # cache the first
            HTTP::Client.objects << object4.save
            HTTP::Client.objects << object5
            HTTP::Client.actors << object4.attributed_to
            HTTP::Client.actors << object5.attributed_to
            HTTP::Client.collections << other.assign(items_iris: [object4.iri, object5.iri])
            subject.assign(last_attempt_at: 10.seconds.ago) # normally set by the task worker
          end

          it "adds the new collection to the horizon" do
            expect{subject.perform}.to change{horizon(subject)}.to([other.iri, hashtag.iri])
          end

          it "fetches the new collection" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{other.iri}")
          end

          it "fetches the uncached object from the collection" do
            subject.perform
            expect(HTTP::Client.requests).to have("GET #{object5.iri}")
          end

          it "persists the uncached object from the collection" do
            expect{subject.perform}.to change{find?(object5.iri)}
          end

          it "sets the next attempt in the near future" do
            subject.perform
            expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
          end
        end
      end

      context "with all objects fetched" do # test the continuation case
        before_each do
          subject.perform(2)
          subject.assign(last_attempt_at: 10.seconds.ago) # normally set by the task worker
        end

        pre_condition { expect(subject.next_attempt_at.not_nil!).to be < 1.minute.from_now }

        it "does not fetch any new objects" do
          expect{subject.perform(1)}.not_to change{ActivityPub::Object.count}
        end

        it "sets the next attempt in the near future" do
          subject.perform(1)
          expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
        end
      end

      context "with some objects fetched" do # test persistent horizon caching
        subject do
          # run task and clear requests for that run.
          # return a wholly new task!
          super.perform(1)
          super.save
          HTTP::Client.requests.clear
          described_class.find(super.id)
        end

        it "does not fetch the collection" do
          subject.perform(1)
          expect(HTTP::Client.requests).not_to have("GET #{hashtag.iri}")
        end

        it "fetches the remaining objects from the collection" do
          subject.perform(1)
          expect(HTTP::Client.requests).to have("GET #{object3.iri}")
        end

        it "persists the remaining objects from the collection" do
          expect{subject.perform(1)}.to change{find?(object3.iri)}
        end
      end

      context "and uncached authors" do
        let(actor2) { object2.attributed_to }
        let(actor3) { object3.attributed_to }

        it "fetches all the uncached authors" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{actor2.iri}", "GET #{actor3.iri}")
        end

        it "persists all the uncached authors" do
          expect{subject.perform}.to change{ {find?(actor2.iri), find?(actor3.iri)}.any?(Nil) }.to(false)
        end
      end

      context "and the task is asynchronously set as complete" do
        # simulate the case where the task is asynchronously set as
        # complete by updating another, duplicate instance of the
        # task.

        before_each do
          subject.dup.complete!
        end

        pre_condition do
          expect(subject.complete).to be_false
        end

        it "does not fetch the hashtag collection" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("GET #{hashtag.iri}")
        end

        it "does not fetch any objects from the collection" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("GET #{object2.iri}", "GET #{object3.iri}")
        end

        it "does not set the next attempt at" do
          subject.perform
          expect(subject.next_attempt_at).to be_nil
        end

        it "sets the task as complete" do
          subject.perform
          expect(subject.complete).to be_true
        end
      end
    end

    context "given many tagged objects, all in multiple collections" do
      let_build_object(1, "https://remote1/tags/hashtag")
      let_build_object(2, "https://remote2/tags/hashtag")
      let_build_object(3, "https://remote3/tags/hashtag")
      let_build(:collection, named: :hashtag1, iri: "https://remote1/tags/hashtag")
      let_build(:collection, named: :hashtag2, iri: "https://remote2/tags/hashtag")
      let_build(:collection, named: :hashtag3, iri: "https://remote3/tags/hashtag")

      before_each do
        # the first two objects are cached
        HTTP::Client.objects << object1.save
        HTTP::Client.objects << object2.save
        HTTP::Client.objects << object3
        HTTP::Client.actors << object1.attributed_to
        HTTP::Client.actors << object2.attributed_to
        HTTP::Client.actors << object3.attributed_to
        HTTP::Client.collections << hashtag1.assign(items_iris: [object1.iri, object2.iri, object3.iri])
        HTTP::Client.collections << hashtag2.assign(items_iris: [object1.iri, object2.iri, object3.iri])
        HTTP::Client.collections << hashtag3.assign(items_iris: [object1.iri, object2.iri, object3.iri])
      end

      it "fetches the remaining object once" do
        subject.perform
        expect(HTTP::Client.requests.count { |request| request === "GET #{object3.iri}"}).to eq(1)
      end

      context "with a blocked author" do
        before_each { object3.attributed_to.save.block! }

        it "fetches the remaining object once" do
          subject.perform
          expect(HTTP::Client.requests.count { |request| request === "GET #{object3.iri}"}).to eq(1)
        end
      end
    end

    context "given many tagged objects, via the Mastodon API" do
      let_build_object(1, "https://remote/tags/hashtag")
      let_build_object(2, "https://remote/tags/hashtag")
      let_build_object(3, "https://remote/tags/hashtag")
      let_build(:collection, named: :hashtag, iri: "https://remote/tags/hashtag")

      before_each do
        # only the first object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.objects << object2
        HTTP::Client.objects << object3
        HTTP::Client.actors << object1.attributed_to
        HTTP::Client.actors << object2.attributed_to
        HTTP::Client.actors << object3.attributed_to
        HTTP::Client.collections << hashtag # intentionally empty
        HTTP::Client.collections["#{object1.origin}/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object1.iri}"},{"uri": "#{object2.iri}"},{"uri": "#{object3.iri}"}]|
      end

      let(node) { subject.state.nodes.first }

      it "fetches the hashtag collection" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{hashtag.iri}")
      end

      it "fetches the API response" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{object1.origin}/api/v1/timelines/tag/hashtag")
      end

      it "fetches an object from the API" do
        subject.perform(1)
        expect(HTTP::Client.requests).to have("GET #{object2.iri}")
      end

      it "persists an object from the API" do
        expect{subject.perform(1)}.to change{find?(object2.iri)}
      end

      it "changes time of last attempt" do
        expect{subject.perform(1)}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform(1)}.to change{node.last_success_at}
      end

      it "sets the next attempt in the immediate future" do
        subject.perform(1)
        expect(subject.next_attempt_at.not_nil!).to be < 1.minute.from_now
      end

      it "fetches the hashtag collection" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{hashtag.iri}")
      end

      it "fetches the API response" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{object1.origin}/api/v1/timelines/tag/hashtag")
      end

      it "fetches all the objects from the API" do
        subject.perform
        expect(HTTP::Client.requests).to have("GET #{object2.iri}", "GET #{object3.iri}")
      end

      it "persists all the objects from the API" do
        expect{subject.perform}.to change{ {find?(object2.iri), find?(object3.iri)}.any?(Nil) }.to(false)
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end

      it "sets the next attempt in the near future" do
        subject.perform
        expect(subject.next_attempt_at.not_nil!).to be_between(80.minutes.from_now, 160.minutes.from_now)
      end

      it "does not raise an error" do
        HTTP::Client.collections["#{object1.origin}/api/v1/timelines/tag/hashtag"] = %Q|[]|
        expect{subject.perform}.not_to raise_error
      end

      it "does not raise an error" do
        HTTP::Client.collections["#{object1.origin}/api/v1/timelines/tag/hashtag"] = %Q|[[]]|
        expect{subject.perform}.not_to raise_error
      end
    end

    context "given tagged objects from more than one origin" do
      let_build_object(1, "https://object1/tags/hashtag")
      let_build_object(2, "https://object2/tags/hashtag", "https://object2/tags/foobar")
      let_build_object(3, "https://object3/tags/hashtag")
      let_build(:collection, named: :collection1, iri: "https://object1/tags/hashtag")
      let_build(:collection, named: :collection2, iri: "https://object2/tags/hashtag")
      let_build(:collection, named: :collection3, iri: "https://object3/tags/hashtag")

      before_each do
        # only the first object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.objects << object2
        HTTP::Client.objects << object3
        HTTP::Client.actors << object1.attributed_to
        HTTP::Client.actors << object2.attributed_to
        HTTP::Client.actors << object3.attributed_to
        HTTP::Client.collections << collection1.assign(items_iris: [object1.iri, object2.iri])
        HTTP::Client.collections << collection2.assign(items_iris: [object2.iri, object3.iri])
        HTTP::Client.collections << collection3.assign(items_iris: [object3.iri])
      end

      let(node) { subject.state.nodes.first }

      it "starts with the initial collection in the horizon" do
        expect(horizon(subject)).to contain_exactly("https://object1/tags/hashtag")
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end

      context "and the second object fetched" do
        before_each { subject.perform(1) }

        pre_condition { expect(HTTP::Client.requests).to have("GET #{object2.iri}") }

        it "adds the second collection to the horizon" do
          expect(horizon(subject)).to contain_exactly("https://object1/tags/hashtag", "https://object2/tags/hashtag")
        end

        it "does not add the collection for the unrelated hashtag to the horizon" do
          expect(horizon(subject)).not_to contain("https://object2/tags/foobar")
        end

        context "and the third object fetched" do
          before_each { subject.perform(1) }

          pre_condition { expect(HTTP::Client.requests).to have("GET #{object3.iri}") }

          it "adds the third collection to the horizon" do
            expect(horizon(subject)).to contain("https://object3/tags/hashtag")
          end
        end
      end

      context "and a undereferenceable object IRI" do
        before_each do
          HTTP::Client.collections << collection1.assign(items_iris: [object1.iri, object2.iri, "https://missing/"])
          HTTP::Client.collections << collection2.assign(items_iris: [object2.iri, object3.iri, "https://missing/"])
        end

        it "only tries to fetch it once" do
          subject.perform
          expect(HTTP::Client.requests.count{ |request| request === "GET https://missing/"}).to eq(1)
        end
      end
    end

    context "given tagged objects from more than one origin, via the Mastodon API" do
      let_build_object(1, "https://object1/tags/hashtag")
      let_build_object(2, "https://object2/tags/hashtag", "https://object2/tags/foobar")
      let_build_object(3, "https://object3/tags/hashtag")
      let_build(:collection, named: :collection1, iri: "https://object1/tags/hashtag")
      let_build(:collection, named: :collection2, iri: "https://object2/tags/hashtag")
      let_build(:collection, named: :collection3, iri: "https://object3/tags/hashtag")

      before_each do
        # only the first object is cached
        HTTP::Client.objects << object1.save
        HTTP::Client.objects << object2
        HTTP::Client.objects << object3
        HTTP::Client.actors << object1.attributed_to
        HTTP::Client.actors << object2.attributed_to
        HTTP::Client.actors << object3.attributed_to
        HTTP::Client.collections << collection1 # intentionally empty
        HTTP::Client.collections << collection2 # intentionally empty
        HTTP::Client.collections << collection3 # intentionally empty
        HTTP::Client.collections["https://object1/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object1.iri}"},{"uri": "#{object2.iri}"}]|
        HTTP::Client.collections["https://object2/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object2.iri}"},{"uri": "#{object3.iri}"}]|
        HTTP::Client.collections["https://object3/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object3.iri}"}]|
      end

      let(node) { subject.state.nodes.first }

      it "starts with the initial collection in the horizon" do
        expect(horizon(subject)).to contain_exactly("https://object1/tags/hashtag")
      end

      it "changes time of last attempt" do
        expect{subject.perform}.to change{node.last_attempt_at}
      end

      it "changes time of last success" do
        expect{subject.perform}.to change{node.last_success_at}
      end

      context "and the second object fetched" do
        before_each { subject.perform(1) }

        pre_condition { expect(HTTP::Client.requests).to have("GET #{object2.iri}") }

        it "adds the second collection to the horizon" do
          expect(horizon(subject)).to contain_exactly("https://object1/tags/hashtag", "https://object2/tags/hashtag")
        end

        it "does not add the collection for the unrelated hashtag to the horizon" do
          expect(horizon(subject)).not_to contain("https://object2/tags/foobar")
        end

        context "and the third object fetched" do
          before_each { subject.perform(1) }

          pre_condition { expect(HTTP::Client.requests).to have("GET #{object3.iri}") }

          it "adds the third collection to the horizon" do
            expect(horizon(subject)).to contain("https://object3/tags/hashtag")
          end
        end
      end

      context "and a undereferenceable object IRI" do
        before_each do
          HTTP::Client.collections["https://object1/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object1.iri}"},{"uri": "#{object2.iri}"},{"uri": "https://missing/"}]|
          HTTP::Client.collections["https://object2/api/v1/timelines/tag/hashtag"] = %Q|[{"uri": "#{object2.iri}"},{"uri": "#{object3.iri}"},{"uri": "https://missing/"}]|
        end

        it "only tries to fetch it once" do
          subject.perform
          expect(HTTP::Client.requests.count{ |request| request === "GET https://missing/"}).to eq(1)
        end
      end
    end
  end

  describe "#path_to" do
    subject do
      described_class.new(
        source: source,
        name: "hashtag"
      ).save
    end

    it "returns the path to the hashtag page" do
      expect(subject.path_to).to eq("/tags/hashtag")
    end
  end
end

Spectator.describe Task::Fetch::Hashtag::State::Node do
  context "creation" do
    it "normalizes and downcases the href" do
      expect(described_class.new(href: "http://OTHER/tags/foorbar/../Hashtag").href).to eq("http://other/tags/hashtag")
    end
  end
end

Spectator.describe Task::Fetch::Hashtag::State do
  subject { described_class.new }

  alias Node = Task::Fetch::Hashtag::State::Node

  let(node1) { Node.new(href: "https://one/hashtag", last_attempt_at: 10.minutes.ago, last_success_at: 30.minutes.ago) }
  let(node2) { Node.new(href: "https://two/hashtag", last_attempt_at: 10.minutes.ago, last_success_at: 40.minutes.ago) }
  let(node3) { Node.new(href: "https://three/hashtag", last_attempt_at: 15.minutes.ago, last_success_at: 10.minutes.ago) }
  let(node4) { Node.new(href: "https://four/hashtag", last_attempt_at: 15.minutes.ago, last_success_at: 20.minutes.ago) }

  before_each do
    subject.nodes = [node1, node2, node3, node4]
  end

  describe "#<<" do
    let(node) { Node.new(href: "http://other/tags/hashtag") }

    pre_condition { expect(subject.nodes).to contain_exactly(node1, node2, node3, node4) }

    it "returns the state instance" do
      expect(subject << node).to eq(subject)
    end

    it "appends the node" do
      expect((subject << node).nodes).to contain_exactly(node1, node2, node3, node4, node).in_any_order
    end
  end

  describe "#includes?" do
    it "returns true if nodes includes node" do
      expect(subject.includes?(Node.new(href: "https://one/hashtag"))).to be_true
    end

    it "returns false if nodes does not include node" do
      expect(subject.includes?(Node.new(href: "https://five/hashtag"))).to be_false
    end
  end

  describe "#prioritize!" do
    it "sorts nodes by difference between last success and last attempt" do
      expect(subject.prioritize!).to eq([node3, node4, node1, node2])
    end
  end

  describe "#last_success_at" do
    it "returns the time of the most recent successful fetch" do
      expect(subject.last_success_at).to eq(node3.last_success_at)
    end

    context "when nodes have never succeeded" do
      before_each do
        node1.last_success_at = Time::UNIX_EPOCH
        node2.last_success_at = Time::UNIX_EPOCH
        node3.last_success_at = Time::UNIX_EPOCH
        node4.last_success_at = Time::UNIX_EPOCH
      end

      it "returns nil" do
        expect(subject.last_success_at).to be_nil
      end
    end
  end
end
