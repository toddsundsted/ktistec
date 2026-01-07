require "../../src/views/view_helper"
require "../../src/models/poll"
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
      Poll::Option.new("Blue", 5),
    ],
    voters_count: 35,
    multiple_choice: false,
  )

  let(env) { env_factory("GET", "/") }

  let(object_emojis) { [] of Tag::Emoji }

  let(timezone) { Time::Location.local }

  context "anonymous user" do
    it "renders vote counts" do
      expect(subject.xpath_nodes("//*[@class='poll-count']/text()")).to contain_exactly("10", "20", "5")
    end

    it "renders disabled inputs" do
      expect(subject.xpath_nodes("//input[@type='radio' and @disabled]").size).to eq(3)
    end

    it "renders disabled vote button" do
      expect(subject.xpath_nodes("//button[@type='submit' and @disabled]").size).to eq(1)
    end
  end

  context "active poll (not voted)" do
    sign_in

    before_each { poll.assign(closed_at: Time.utc + 1.day).save }

    it "renders options" do
      expect(subject.xpath_nodes("//*[@class='option-name']/text()")).to contain_exactly("Red", "Green", "Blue")
    end

    it "does not render vote counts" do
      expect(subject.xpath_nodes("//*[@class='poll-count']")).to be_empty
    end

    it "renders option bars" do
      expect(subject.xpath_nodes("//*[@class='poll-option-bar']").size).to eq(3)
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

    it "renders radio inputs" do
      expect(subject.xpath_nodes("//input[@type='radio']").size).to eq(3)
    end

    it "renders enabled inputs" do
      expect(subject.xpath_nodes("//input[@type='radio' and not(@disabled)]").size).to eq(3)
    end

    it "renders enabled vote button" do
      expect(subject.xpath_nodes("//button[@type='submit' and @data-poll-target='voteButton']").size).to eq(1)
    end
  end

  context "draft poll" do
    sign_in

    before_each do
      poll.question.assign(
        iri: "https://test.test/objects/#{Ktistec::Util.id}",
        attributed_to: env.account.actor, # author viewing own poll
        published: nil
      ).save
    end

    it "does not render vote counts" do
      expect(subject.xpath_nodes("//*[@class='poll-count']")).to be_empty
    end

    it "renders enabled inputs" do
      expect(subject.xpath_nodes("//input[@type='radio' and not(@disabled)]").size).to eq(3)
    end

    it "renders vote button as type='button'" do
      expect(subject.xpath_nodes("//button[@type='button']").size).to eq(1)
    end
  end

  context "published poll" do
    sign_in

    before_each do
      poll.question.assign(
        iri: "https://test.test/objects/#{Ktistec::Util.id}",
        attributed_to: env.account.actor, # author viewing own poll
        published: Time.utc
      ).save
    end

    it "renders vote counts" do
      expect(subject.xpath_nodes("//*[@class='poll-count']/text()")).to contain_exactly("10", "20", "5")
    end

    it "renders disabled inputs" do
      expect(subject.xpath_nodes("//input[@type='radio' and @disabled]").size).to eq(3)
    end

    it "renders disabled vote button" do
      expect(subject.xpath_nodes("//button[@type='submit' and @disabled]").size).to eq(1)
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

    it "renders vote counts" do
      expect(subject.xpath_nodes("//*[@class='poll-count']/text()")).to contain_exactly("10", "20", "5")
    end

    it "renders disabled inputs" do
      expect(subject.xpath_nodes("//input[@type='radio' and @disabled]").size).to eq(3)
    end

    it "renders disabled vote button" do
      expect(subject.xpath_nodes("//button[@type='submit' and @disabled]").size).to eq(1)
    end
  end

  context "multiple-choice poll" do
    before_each { poll.assign(multiple_choice: true).save }

    it "indicates multiple selections allowed" do
      expect(subject.to_s).to contain("Multiple choice")
    end

    it "renders checkbox inputs" do
      expect(subject.xpath_nodes("//input[@type='checkbox']").size).to eq(3)
    end
  end

  context "poll without voters_count" do
    before_each { poll.assign(voters_count: nil).save }

    it "shows total votes" do
      expect(subject.to_s).to contain("35 votes")
    end
  end

  context "identification" do
    before_each { poll.question.assign(id: 1234_i64) }

    it "uses the ID of the question in the attribute" do
      expect(subject.xpath_nodes("//turbo-frame/@id")).to contain_exactly("poll-#{poll.question.id}")
    end
  end
end
