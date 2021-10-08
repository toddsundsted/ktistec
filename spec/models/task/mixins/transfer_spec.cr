require "../../../../src/models/task"
require "../../../../src/models/task/mixins/transfer"

require "../../../spec_helper/model"
require "../../../spec_helper/network"
require "../../../spec_helper/register"

class FooBarTransfer < Task
  include Task::Transfer
end

Spectator.describe Task::Transfer do
  setup_spec

  let(transferer) do
    register(with_keys: true).actor
  end
  let(activity) do
    ActivityPub::Activity.new(iri: "https://test.test/activities/activity")
  end

  let!(local_recipient) do
    username = random_string
    ActivityPub::Actor.new(
      iri: "https://test.test/actors/#{username}",
      inbox: "https://test.test/actors/#{username}/inbox"
    ).save
  end

  let!(remote_recipient) do
    username = random_string
    ActivityPub::Actor.new(
      iri: "https://remote/actors/#{username}",
      inbox: "https://remote/actors/#{username}/inbox"
    ).save
  end

  describe "#transfer" do
    subject { FooBarTransfer.new }

    it "dereferences the recipient" do
      subject.transfer(activity, from: transferer, to: ["https://unknown-recipient"])
      expect(HTTP::Client.requests).to have("GET https://unknown-recipient")
    end

    it "does not dereference the transferer" do
      subject.transfer(activity, from: transferer, to: [transferer.iri])
      expect(HTTP::Client.requests).to be_empty
    end

    it "sends the activity to the local recipient" do
      subject.transfer(activity, from: transferer, to: [local_recipient.iri])
      expect(HTTP::Client.requests).to have("POST #{local_recipient.inbox}")
    end

    it "sends the activity to the remote recipient" do
      subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
      expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
    end

    it "does not send the activity to the transferer" do
      subject.transfer(activity, from: transferer, to: [transferer.iri])
      expect(HTTP::Client.requests).to be_empty
    end
  end
end
