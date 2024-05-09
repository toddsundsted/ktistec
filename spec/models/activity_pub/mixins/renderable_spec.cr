require "../../../../src/models/activity_pub/mixins/renderable"

require "../../../spec_helper/base"

class RenderableModel
  include Ktistec::Model
  include Ktistec::Model::Renderable

  @[Persistent]
  property content : String?

  @[Persistent]
  property media_type : String?
end

Spectator.describe Ktistec::Model::Renderable do
  describe ".new" do
    it "includes Ktistec::Model::Renderable" do
      expect(RenderableModel.new).to be_a(Ktistec::Model::Renderable)
    end
  end

  describe "#to_html" do
    it "renders HTML as HTML" do
      subject = RenderableModel.new(content: "<p>this is a test</p>\n", media_type: "text/html")
      expect(subject.to_html).to eq("<p>this is a test</p>\n")
    end

    it "renders Markdown as HTML" do
      subject = RenderableModel.new(content: "this is a test\n", media_type: "text/markdown")
      expect(subject.to_html).to eq("<p>this is a test</p>\n")
    end
  end
end
