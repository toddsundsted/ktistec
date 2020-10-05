require "../../spec_helper"

class FooBarObject < ActivityPub::Object
end

Spectator.describe ActivityPub::Object do
  setup_spec

  context "when validating" do
    let!(object) { described_class.new(iri: "https://test.test/foo_bar").save }

    it "must be present" do
      expect(described_class.new.valid?).to be_false
    end

    it "must be an absolute URI" do
      expect(described_class.new(iri: "/some_object").valid?).to be_false
    end

    it "must be unique" do
      expect(described_class.new(iri: "https://test.test/foo_bar").valid?).to be_false
    end

    it "is valid" do
      expect(described_class.new(iri: "https://test.test/#{random_string}").save.valid?).to be_true
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/foo_bar",
        "@type":"FooBarObject",
        "published":"2016-02-15T10:20:30Z",
        "attributedTo":{
          "id":"attributed to link"
        },
        "inReplyTo":"in reply to link",
        "replies":{
          "id":"replies link"
        },
        "to":"to link",
        "cc":["cc link"],
        "summary":"abc",
        "content":"abc",
        "mediaType":"xyz",
        "attachment":[
          {
            "url":"attachment link",
            "mediaType":"type"
          }
        ],
        "url":"url link"
      }
    JSON
  end

  describe ".from_json_ld" do
    it "instantiates the subclass" do
      object = described_class.from_json_ld(json)
      expect(object.class).to eq(FooBarObject)
    end

    it "creates a new instance" do
      object = described_class.from_json_ld(json).save
      expect(object.iri).to eq("https://test.test/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("to link", "https://www.w3.org/ns/activitystreams#Public")
        object = described_class.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      object = described_class.new.from_json_ld(json).save
      expect(object.iri).to eq("https://test.test/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.attributed_to_iri).to eq("attributed to link")
      expect(object.in_reply_to_iri).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("cc link", "https://www.w3.org/ns/activitystreams#Public")
        object = described_class.new.from_json_ld(json).save
        expect(object.visible).to be_true
      end
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      object = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(object.to_json_ld)).to eq(object)
    end
  end

  context "when threaded" do
    subject { described_class.new(iri: "https://test.test/objects/#{random_string}").save }

    macro reply_to!(object, reply)
      let!({{reply}}) do
        described_class.new(
          iri: "https://test.test/objects/#{random_string}",
          in_reply_to: {{object}}
        ).save
      end
    end

    # Nesting:
    # S           id=1
    #   1         id=2
    #     2       id=4
    #       3     id=5
    #   4         id=3
    #     5       id=6

    reply_to!(subject, object1)
    reply_to!(subject, object4)
    reply_to!(object1, object2)
    reply_to!(object2, object3)
    reply_to!(object4, object5)

    describe "#thread" do
      it "returns all replies properly nested" do
        expect(subject.thread).to eq([subject, object1, object2, object3, object4, object5])
        expect(object1.thread).to eq([subject, object1, object2, object3, object4, object5])
        expect(object5.thread).to eq([subject, object1, object2, object3, object4, object5])
      end

      it "omits deleted replies but includes their children" do
        object4.delete
        expect(subject.thread).to eq([subject, object1, object2, object3, object5])
      end

      it "omits destroyed replies and their children" do
        object4.destroy
        expect(subject.thread).to eq([subject, object1, object2, object3])
      end
    end

    describe "#ancestors" do
      it "returns all ancestors" do
        expect(subject.ancestors).to eq([subject])
        expect(object3.ancestors).to eq([object3, object2, object1, subject])
        expect(object5.ancestors).to eq([object5, object4, subject])
      end

      it "omits deleted replies but includes their parents" do
        object1.delete
        expect(object3.ancestors).to eq([object3, object2, subject])
      end

      it "omits destroyed replies and their parents" do
        object1.destroy
        expect(object3.ancestors).to eq([object3, object2])
      end
    end
  end

  describe "#local" do
    it "indicates if the object is local" do
      expect(described_class.new(iri: "https://test.test/foo_bar").local).to be_true
      expect(described_class.new(iri: "https://remote/foo_bar").local).to be_false
    end
  end
end
