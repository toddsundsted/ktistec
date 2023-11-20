require "../../../../src/models/task"
require "../../../../src/models/task/mixins/transfer"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/network"

class FooBarTransfer < Task
  include Task::Transfer

  @source_iri = ""
  @subject_iri  = ""
end

class Regex
  def ===(other : Task::Failure)
    other.description =~ self
  end
end

Spectator.describe Task::Transfer do
  setup_spec

  let(transferer) do
    register.actor
  end

  let_build(:activity)

  let_create!(:actor, named: :local_recipient, iri: "https://test.test/actors/local")
  let_create!(:actor, named: :remote_recipient, iri: "https://remote/actors/remote")

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

    context "given an OpenSSL error" do
      before_each do
        # simulate an OpenSSL error
        local_recipient.assign(inbox: "https://remote/openssl-error").save
      end

      it "doesn't raise an error" do
        expect{subject.transfer(activity, from: transferer, to: [local_recipient.iri])}.
          not_to raise_error(OpenSSL::Error)
      end

      it "stores the failure reason" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(subject.failures).to have(/OpenSSL::Error: .* #{local_recipient.inbox}/)
      end
    end

    context "given a Socket error" do
      before_each do
        # simulate a Socket error
        local_recipient.assign(inbox: "https://remote/socket-error").save
      end

      it "doesn't raise an error" do
        expect{subject.transfer(activity, from: transferer, to: [local_recipient.iri])}.
          not_to raise_error(Socket::Error)
      end

      it "stores the failure reason" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(subject.failures).to have(/Socket::Error: .* #{local_recipient.inbox}/)
      end
    end
  end
end
