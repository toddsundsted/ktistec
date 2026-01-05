require "../../../../src/models/activity_pub/object/note"
require "../../../../src/models/activity_pub/object/question"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Object::Note do
  setup_spec

  describe "#before_save" do
    let_create(:question)
    let_create!(
      :poll,
      question: question,
      options: [
        Poll::Option.new("Option A", 0),
        Poll::Option.new("Option B", 0),
      ],
    )

    context "when Note is a vote" do
      let_build(
        :note,
        name: "Option A",
        in_reply_to: question,
      )

      it "sets special to 'vote'" do
        expect { note.save }.to change { note.special }.from(nil).to("vote")
      end
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

    context "when special is set" do
      let_build(
        :note,
        name: "Option A",
        in_reply_to: question,
        special: "other",
      )

      it "does not set special to 'vote'" do
        expect { note.save }.not_to change { note.special }
      end
    end
  end
end
