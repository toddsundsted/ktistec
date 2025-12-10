require "../../src/views/view_helper"
require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe "views/partials/object/content/poll.html.slang" do
  setup_spec

  include Ktistec::Controller
  include Ktistec::ViewHelper::ClassMethods

  subject do
    begin
      XML.parse_html(render "./src/views/partials/object/content/poll.html.slang")
    rescue XML::Error
      XML.parse_html("<div/>").document
    end
  end

  let_create!(
    :poll,
    options: [
      Poll::Option.new("Red", 10),
      Poll::Option.new("Green", 20),
      Poll::Option.new("Blue", 5)
    ],
    voters_count: 35,
    multiple_choice: false,
  )

  let(object_emojis) { [] of Tag::Emoji }

  let(timezone) { Time::Location.local }

  context "active poll" do
    before_each { poll.assign(closed_at: Time.utc + 1.day).save }

    it "renders options" do
      expect(subject.xpath_nodes("//*[@class='poll-option-name']/text()")).to contain_exactly("Red", "Green", "Blue")
    end

    it "renders vote counts" do
      expect(subject.xpath_nodes("//*[@class='count']/text()")).to contain_exactly("10", "20", "5")
    end

    it "renders total voters" do
      expect(subject.to_s).to contain("35 voters")
    end

    it "renders time until expiration" do
      expect(subject.to_s).to contain("Ends about 1 day from now")
    end

    it "indicates single vs multiple choice" do
      expect(subject.to_s).not_to contain("Multiple choice")
    end
  end

  context "expired poll" do
    before_each { poll.assign(closed_at: Time.utc - 1.hour).save }

    it "indicates the poll has ended" do
      expect(subject.to_s).to contain("Poll ended")
    end

    it "renders when poll closed" do
      expect(subject.to_s).to match(/\w+ \d+, \d{4}/)
    end
  end

  context "multiple-choice poll" do
    before_each { poll.assign(multiple_choice: true).save }

    it "indicates multiple selections allowed" do
      expect(subject.to_s).to contain("Multiple choice")
    end
  end

  context "poll without voters_count" do
    before_each { poll.assign(voters_count: nil).save }

    it "shows total votes" do
      expect(subject.to_s).to contain("35 votes")
    end
  end
end
