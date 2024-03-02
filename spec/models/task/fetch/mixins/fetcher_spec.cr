require "../../../../../src/models/task/fetch/mixins/fetcher"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"
require "../../../../spec_helper/network"

Spectator.describe Task::Fetch::Fetcher do
  setup_spec

  let_create(:actor, named: :source, with_keys: true)

  class TestFetcher
    include Task::Fetch::Fetcher

    class State
      property failures : Int32 = 0
    end

    property state : State { State.new }

    property source : ActivityPub::Actor

    def initialize(@source)
    end

    def find_or_fetch_object(*args)
      super(*args)
    end

    def calculate_next_attempt_at(*args)
      super(*args)
    end
  end

  describe "#find_or_fetch_object" do
    subject { TestFetcher.new(source: source) }

    context "given an object" do
      let_build(:object)
      let(:actor) { object.attributed_to }

      before_each do
        HTTP::Client.objects << object
        HTTP::Client.actors << actor
      end

      it "fetches the object" do
        subject.find_or_fetch_object(object.iri)
        expect(HTTP::Client.requests).to have("GET #{object.iri}")
      end

      it "persists the object" do
        expect{subject.find_or_fetch_object(object.iri)}.to change{object.class.find?(object.iri)}
      end

      it "fetches the actor" do
        subject.find_or_fetch_object(object.iri)
        expect(HTTP::Client.requests).to have("GET #{actor.iri}")
      end

      it "persists the actor" do
        expect{subject.find_or_fetch_object(object.iri)}.to change{actor.class.find?(actor.iri)}
      end

      it "returns the object" do
        expect(subject.find_or_fetch_object(object.iri).last).to eq(object.class.find(object.iri))
      end

      it "returns true" do
        expect(subject.find_or_fetch_object(object.iri).first).to be_true
      end

      context "that can't be dereferenced" do
        before_each do
          object.assign(iri: "https://example.com/invalid")
        end

        it "fetches the object" do
          subject.find_or_fetch_object(object.iri)
          expect(HTTP::Client.requests).to have("GET #{object.iri}")
        end

        it "does not persist the object" do
          expect{subject.find_or_fetch_object(object.iri)}.not_to change{object.class.find?(object.iri)}
        end

        it "does not return the object" do
          expect(subject.find_or_fetch_object(object.iri).last).to be_nil
        end

        it "returns false" do
          expect(subject.find_or_fetch_object(object.iri).first).to be_false
        end

        context "given a prior failure" do
          before_each do
            subject.find_or_fetch_object(object.iri)
            HTTP::Client.requests.clear
          end

          it "does not fetch the object" do
            subject.find_or_fetch_object(object.iri)
            expect(HTTP::Client.requests).not_to have("GET #{object.iri}")
          end
        end
      end

      context "that can't be dereferenced" do
        before_each do
          HTTP::Client.objects << object.assign(attributed_to_iri: "https://example.com/invalid")
          actor.assign(iri: "https://example.com/invalid")
        end

        it "fetches the actor" do
          subject.find_or_fetch_object(object.iri)
          expect(HTTP::Client.requests).to have("GET #{actor.iri}")
        end

        it "does not persist the actor" do
          expect{subject.find_or_fetch_object(object.iri)}.not_to change{actor.class.find?(actor.iri)}
        end

        it "does not return the object" do
          expect(subject.find_or_fetch_object(object.iri).last).to be_nil
        end

        it "returns false" do
          expect(subject.find_or_fetch_object(object.iri).first).to be_false
        end

        context "given a prior failure" do
          before_each do
            subject.find_or_fetch_object(object.iri)
            HTTP::Client.requests.clear
          end

          it "does not fetch the actor" do
            subject.find_or_fetch_object(object.iri)
            expect(HTTP::Client.requests).not_to have("GET #{actor.iri}")
          end
        end
      end

      context "that is already cached" do
        before_each { object.save }

        it "does not fetch the object" do
          subject.find_or_fetch_object(object.iri)
          expect(HTTP::Client.requests).not_to have("GET #{object.iri}")
        end

        it "does not persist the object" do
          expect{subject.find_or_fetch_object(object.iri)}.not_to change{object.class.find?(object.iri)}
        end

        it "does not fetch the actor" do
          subject.find_or_fetch_object(object.iri)
          expect(HTTP::Client.requests).not_to have("GET #{actor.iri}")
        end

        it "does not persist the actor" do
          expect{subject.find_or_fetch_object(object.iri)}.not_to change{actor.class.find?(actor.iri)}
        end

        it "returns the object" do
          expect(subject.find_or_fetch_object(object.iri).last).to eq(object.class.find(object.iri))
        end

        it "returns false" do
          expect(subject.find_or_fetch_object(object.iri).first).to be_false
        end
      end

      context "from a blocked actor" do
        before_each { object.attributed_to.save.block! }

        it "does not persist the blocked object" do
          expect{subject.find_or_fetch_object(object.iri)}.to_not change{object.class.find?(object.iri)}
        end

        it "does not persist the blocked actor" do
          expect{subject.find_or_fetch_object(object.iri)}.to_not change{actor.class.find?(actor.iri)}
        end

        it "does not return the object" do
          expect(subject.find_or_fetch_object(object.iri).last).to be_nil
        end

        it "returns false" do
          expect(subject.find_or_fetch_object(object.iri).first).to be_false
        end
      end
    end
  end

  describe "#calculate_next_attempt_at" do
    subject { TestFetcher.new(source: source) }

    ImmediateFuture = Task::Fetch::Horizon::ImmediateFuture
    NearFuture = Task::Fetch::Horizon::NearFuture
    FarFuture = Task::Fetch::Horizon::FarFuture

    it "returns a time in the immediate future" do
      expect(subject.calculate_next_attempt_at(ImmediateFuture)).to be < 1.minute.from_now
    end

    it "does not increment the failure counter" do
      expect{subject.calculate_next_attempt_at(ImmediateFuture)}.not_to change{subject.failures}
    end

    it "returns a time in the near future" do
      expect(subject.calculate_next_attempt_at(NearFuture)).to be_between(80.minutes.from_now, 160.minutes.from_now)
    end

    it "does not increment the failure counter" do
      expect{subject.calculate_next_attempt_at(NearFuture)}.not_to change{subject.failures}
    end

    it "returns a time in the far future" do
      expect(subject.calculate_next_attempt_at(FarFuture)).to be_between(170.minutes.from_now, 310.minutes.from_now)
    end

    it "increments the failures counter" do
      expect{subject.calculate_next_attempt_at(FarFuture)}.to change{subject.failures}.to(1)
    end

    context "given a prior failure" do
      before_each { subject.state.failures = 1 }

      it "resets the failure counter" do
        expect{subject.calculate_next_attempt_at(ImmediateFuture)}.to change{subject.failures}.to(0)
      end

      it "resets the failure counter" do
        expect{subject.calculate_next_attempt_at(NearFuture)}.to change{subject.failures}.to(0)
      end

      it "returns a time even further in the future" do
        expect(subject.calculate_next_attempt_at(FarFuture)).to be_between(350.minutes.from_now, 610.minutes.from_now)
      end

      it "increments the failure counter" do
        expect{subject.calculate_next_attempt_at(FarFuture)}.to change{subject.failures}.to(2)
      end
    end

    context "given six prior failures" do
      before_each { subject.state.failures = 6 }

      it "returns a time the maximum distance in the future" do
        expect(subject.calculate_next_attempt_at(FarFuture)).to be_between(122.hours.from_now, 214.hours.from_now)
      end

      it "increments the failure counter" do
        expect{subject.calculate_next_attempt_at(FarFuture)}.to change{subject.failures}.to(7)
      end
    end
  end
end
