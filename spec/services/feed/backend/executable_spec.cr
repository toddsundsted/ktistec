require "../../../../src/services/feed/backend/executable"
require "../../../../src/models/feed"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Feed::Backend::Executable do
  setup_spec

  subject { described_class.new(File.join("etc", "judges", "summarize")) }

  describe "#judge" do
    let_build(:feed, name: "Test", backend: "summarize")
    let_build(:object)

    it "fails permanently" do
      expect { subject.judge(feed, [object]) }.to raise_error(Feed::Backend::PermanentError)
    end
  end
end
