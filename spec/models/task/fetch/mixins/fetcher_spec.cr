require "../../../../../src/models/task/fetch/mixins/fetcher"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"
require "../../../../spec_helper/network"

Spectator.describe Task::Fetch::Fetcher do
  setup_spec

  let_create(:actor, named: :source, with_keys: true)

  class TestFetcher
    include Task::Fetch::Fetcher

    property source : ActivityPub::Actor

    def initialize(@source)
    end

    def find_or_fetch_object(*args)
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
end
