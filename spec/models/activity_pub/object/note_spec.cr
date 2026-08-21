require "../../../../src/models/activity_pub/object/note"
require "../../../../src/models/activity_pub/object/question"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Object::Note do
  setup_spec

  describe "#before_save" do
    let_create(
      :question,
      published: Time.utc,
      local: true,
    )
    let_create!(
      :poll,
      question: question,
      options: [
        Poll::Option.new("Option A", 0),
        Poll::Option.new("Option B", 0),
      ],
    )

    let(author) { question.attributed_to }

    let_create(:actor, named: :voter, local: false)

    let_build(
      :note,
      name: "Option A",
      in_reply_to: question,
      attributed_to: voter,
    )

    it "sets special to 'vote'" do
      expect { note.save }.to change { note.special }.from(nil).to("vote")
    end

    context "when Note has content" do
      let_build(
        :note,
        name: "Option A",
        content: "I choose A",
        in_reply_to: question,
      )

      it "does not set special to 'vote'" do
        note.save
        expect(note.special).to be_nil
      end
    end

    context "when name does not match poll option" do
      let_build(
        :note,
        name: "Invalid Option",
        in_reply_to: question,
      )

      it "does not set special to 'vote'" do
        note.save
        expect(note.special).to be_nil
      end
    end

    context "when Note is not in reply to a Question" do
      let_create(:object)
      let_build(
        :note,
        name: "Some Name",
        in_reply_to: object,
      )

      it "does not set special to 'vote'" do
        note.save
        expect(note.special).to be_nil
      end
    end

    context "when the poll is closed" do
      before_each { poll.assign(closed_at: 1.minute.ago).save(skip_validation: true) }

      it "sets special to 'ignored_vote'" do
        expect { note.save }.to change { note.special }.from(nil).to("ignored_vote")
      end

      context "but the question is remote" do
        let_create(:question, local: false)

        it "sets special to 'vote'" do
          expect { note.save }.to change { note.special }.from(nil).to("vote")
        end
      end
    end

    context "when the question is not public" do
      before_each { question.assign(visible: false).save }

      it "sets special to 'ignored_vote'" do
        expect { note.save }.to change { note.special }.from(nil).to("ignored_vote")
      end

      context "and the voter is addressed" do
        before_each { question.assign(to: [voter.iri]).save }

        it "sets special to 'vote'" do
          expect { note.save }.to change { note.special }.from(nil).to("vote")
        end
      end

      context "and the author's followers are addressed" do
        before_each { question.assign(to: [author.followers.not_nil!]).save }

        it "sets special to 'ignored_vote'" do
          expect { note.save }.to change { note.special }.from(nil).to("ignored_vote")
        end

        context "and the voter follows the author" do
          let_create!(:follow_relationship, actor: voter, object: author, confirmed: true)

          it "sets special to 'vote'" do
            expect { note.save }.to change { note.special }.from(nil).to("vote")
          end
        end
      end
    end

    context "when the voter has already voted" do
      # `note` votes for "Option A"

      let(earlier_vote) { "Option B" }

      let_create!(
        :note,
        named: nil,
        name: earlier_vote,
        content: nil,
        in_reply_to: question,
        attributed_to: voter,
        special: "vote",
      )

      it "sets special to 'ignored_vote'" do
        expect { note.save }.to change { note.special }.from(nil).to("ignored_vote")
      end

      context "and the poll allows multiple choices" do
        let_create!(
          :poll,
          question: question,
          multiple_choice: true,
          options: [
            Poll::Option.new("Option A", 0),
            Poll::Option.new("Option B", 0),
          ],
        )

        it "sets special to 'vote'" do
          expect { note.save }.to change { note.special }.from(nil).to("vote")
        end

        context "but the voter has already voted for this option" do
          let(earlier_vote) { "Option A" }

          it "sets special to 'ignored_vote'" do
            expect { note.save }.to change { note.special }.from(nil).to("ignored_vote")
          end
        end
      end
    end

    context "when the vote is already recorded" do
      before_each { note.save }

      pre_condition { expect(note.special).to eq("vote") }

      it "does not change the recorded option" do
        note.assign(name: "Option B").save
        expect(ActivityPub::Object.find(note.iri).name).to eq("Option A")
      end
    end

    context "when the vote is already ignored" do
      before_each { note.assign(special: "ignored_vote").save }

      pre_condition { expect(note.special).to eq("ignored_vote") }

      it "does not change the recorded option" do
        note.assign(name: "Option B").save
        expect(ActivityPub::Object.find(note.iri).name).to eq("Option A")
      end
    end
  end
end
