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
  def ===(other : Task::Transfer::Failure)
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

      it "does not mark the recipient as down" do
        expect{subject.transfer(activity, from: transferer, to: [local_recipient.iri])}.
          not_to change{local_recipient.down?}
      end
    end

    context "given an IO error" do
      before_each do
        # simulate an IO error
        local_recipient.assign(inbox: "https://remote/io-error").save
      end

      it "doesn't raise an error" do
        expect{subject.transfer(activity, from: transferer, to: [local_recipient.iri])}.
          not_to raise_error(IO::Error)
      end

      it "stores the failure reason" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(subject.failures).to have(/IO::Error: .* #{local_recipient.inbox}/)
      end

      it "does not mark the recipient as down" do
        expect{subject.transfer(activity, from: transferer, to: [local_recipient.iri])}.
          not_to change{local_recipient.down?}
      end
    end

    def failed_transfer_factory(recipient_iri = nil, recipient = false, **options)
      recipient = actor_factory unless recipient_iri || recipient.nil? || recipient
      failure = Task::Transfer::Failure.new(recipient.as(ActivityPub::Actor).iri, "failure")
      FooBarTransfer.new(**{running: false, complete: true, failures: [failure]}.merge(options))
    end

    context "given three errors for the same recipient within the last ten days" do
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 7.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 4.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 1.day.ago)

      before_each do
        # simulate an error
        remote_recipient.assign(inbox: "https://remote/openssl-error").save
      end

      it "marks the recipient as down" do
        expect{subject.transfer(activity, from: transferer, to: [remote_recipient.iri])}.
          to change{remote_recipient.reload!.down?}.to(true)
      end
    end

    context "given only two errors for the same recipient" do
      let_create!(:failed_transfer, named: nil, recipient: local_recipient, created_at: 6.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 4.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 1.day.ago)

      before_each do
        # simulate an error
        remote_recipient.assign(inbox: "https://remote/openssl-error").save
      end

      it "does not mark the recipient as down" do
        expect{subject.transfer(activity, from: transferer, to: [remote_recipient.iri])}.
          not_to change{remote_recipient.reload!.down?}.from(false)
      end
    end

    context "given only two errors within the last ten days" do
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 12.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 4.days.ago)
      let_create!(:failed_transfer, named: nil, recipient: remote_recipient, created_at: 1.day.ago)

      before_each do
        # simulate an error
        remote_recipient.assign(inbox: "https://remote/openssl-error").save
      end

      it "does not mark the recipient as down" do
        expect{subject.transfer(activity, from: transferer, to: [remote_recipient.iri])}.
          not_to change{remote_recipient.reload!.down?}.from(false)
      end
    end

    context "when the recipient is down" do
      before_each do
        remote_recipient.assign(down_at: Time.utc).save
      end

      it "does not send the activity to the recipient" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).to be_empty
      end
    end
  end
end
