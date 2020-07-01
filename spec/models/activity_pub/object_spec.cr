require "../../spec_helper"

Spectator.describe ActivityPub::Object do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

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

    it "may not be visible if remote" do
      expect(described_class.new(iri: "https://remote/0", visible: true).valid?).to be_false
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/foo_bar",
        "@type":"Object",
        "published":"2016-02-15T10:20:30Z",
        "inReplyTo":"in reply to link",
        "replies":{
          "id":"replies link"
        },
        "attributedTo":{
          "id":"attributed to link"
        },
        "to":"to link",
        "cc":["cc link"],
        "summary":"abc",
        "content":"abc",
        "mediaType":"xyz",
        "source":{
          "content":"one",
          "mediaType":"two"
        },
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
    it "creates a new instance" do
      object = described_class.from_json_ld(json).save
      expect(object.iri).to eq("https://test.test/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.in_reply_to).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.attributed_to).to eq(["attributed to link"])
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.source).to eq(ActivityPub::Object::Source.new("one", "two"))
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      object = described_class.new.from_json_ld(json).save
      expect(object.iri).to eq("https://test.test/foo_bar")
      expect(object.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(object.in_reply_to).to eq("in reply to link")
      expect(object.replies).to eq("replies link")
      expect(object.attributed_to).to eq(["attributed to link"])
      expect(object.to).to eq(["to link"])
      expect(object.cc).to eq(["cc link"])
      expect(object.summary).to eq("abc")
      expect(object.content).to eq("abc")
      expect(object.media_type).to eq("xyz")
      expect(object.source).to eq(ActivityPub::Object::Source.new("one", "two"))
      expect(object.attachments).to eq([ActivityPub::Object::Attachment.new("attachment link", "type")])
      expect(object.urls).to eq(["url link"])
    end
  end

  context "when rendering" do
    it "renders an identical instance" do
      object = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(render "src/views/objects/object.json.ecr")).to eq(object)
    end
  end
end
