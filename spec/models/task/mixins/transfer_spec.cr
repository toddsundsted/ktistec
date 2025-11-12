require "../../../../src/models/task"
require "../../../../src/models/task/mixins/transfer"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/network"

class FooBarTransfer < Task
  include Task::Transfer

  @source_iri = ""
  @subject_iri  = ""

  # redefine private method as public for testing
  def sanitize_log_message(message : String, max_length : Int32 = 200) : String
    super
  end
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

  def failed_transfer_factory(recipient_iri = nil, recipient = false, created_at = Time.utc)
    recipient = actor_factory unless recipient_iri || recipient.nil? || recipient
    failure = Task::Transfer::Failure.new(recipient.as(ActivityPub::Actor).iri, "failure", created_at)
    FooBarTransfer.new(**{running: false, complete: true, failures: [failure], created_at: created_at})
  end

  describe "#sanitize_log_message" do
    subject { FooBarTransfer.new }

    it "returns short messages without newlines unchanged" do
      message = "short message"
      expect(subject.sanitize_log_message(message)).to eq(message)
    end

    it "replaces newline with literal '\\n'" do
      message = "line 1\nline 2\nline 3"
      expect(subject.sanitize_log_message(message)).to eq("line 1\\nline 2\\nline 3")
    end

    it "replaces CRLF with literal '\\n'" do
      message = "line 1\r\nline 2\r\nline 3"
      expect(subject.sanitize_log_message(message)).to eq("line 1\\nline 2\\nline 3")
    end

    it "truncates messages longer than 200 characters" do
      message = "a" * 250
      result = subject.sanitize_log_message(message)
      expect(result.size).to eq(200)
      expect(result).to end_with("...")
    end

    it "respects `max_length` parameter" do
      message = "a" * 100
      result = subject.sanitize_log_message(message, max_length: 50)
      expect(result.size).to eq(50)
      expect(result).to end_with("...")
    end
  end

  describe "#transfer" do
    subject { FooBarTransfer.new }

    it "dereferences the recipient" do
      subject.transfer(activity, from: transferer, to: ["https://unknown-recipient/"])
      expect(HTTP::Client.requests).to have("GET https://unknown-recipient/")
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

    context "when the recipient is down" do
      before_each do
        remote_recipient.assign(down_at: Time.utc).save
      end

      it "does not send the activity to the recipient" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).to be_empty
      end
    end

    context "when recipient has a shared inbox" do
      before_each do
        remote_recipient.assign(shared_inbox: "https://remote/shared-inbox").save
      end

      it "sends the activity to the shared inbox" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).to have("POST https://remote/shared-inbox")
        expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
      end
    end

    context "given another remote recipient" do
      let_create!(:actor, named: :another_recipient, iri: "https://remote/actors/another")

      context "when multiple recipients share the same shared inbox" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/shared-inbox").save
          another_recipient.assign(shared_inbox: "https://remote/shared-inbox").save
        end

        it "delivers once to the shared inbox" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST https://remote/shared-inbox")
          expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
          expect(HTTP::Client.requests).not_to have("POST #{another_recipient.inbox}")
        end
      end

      context "when delivery to the shared inbox fails" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/openssl-error").save
          another_recipient.assign(shared_inbox: "https://remote/openssl-error").save
        end

        it "tracks failures for each recipient" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(subject.failures.map(&.recipient)).to contain_exactly(remote_recipient.iri, another_recipient.iri)
        end
      end

      context "when mixing recipients with and without a shared inbox" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/shared-inbox").save
        end

        it "delivers to shared and individual inboxes appropriately" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST https://remote/shared-inbox")
          expect(HTTP::Client.requests).to have("POST #{another_recipient.inbox}")
          expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
        end
      end
    end
  end

  describe ".is_recipient_down?" do
    let_build(:actor, named: :recipient, iri: "https://remote/recipient")

    # failures at various time points
    let_build(:failed_transfer, named: :failure_7d, recipient: recipient, created_at: 7.days.ago)
    let_build(:failed_transfer, named: :failure_5d, recipient: recipient, created_at: 5.days.ago)
    let_build(:failed_transfer, named: :failure_4d, recipient: recipient, created_at: 4.days.ago)
    let_build(:failed_transfer, named: :failure_3d, recipient: recipient, created_at: 3.days.ago)
    let_build(:failed_transfer, named: :failure_2d, recipient: recipient, created_at: 2.days.ago)
    let_build(:failed_transfer, named: :failure_1d, recipient: recipient, created_at: 1.day.ago)

    let_build(:actor, named: :other, iri: "https://remote/other")

    # failure to other recipient
    let(failure_other_5d) do
      FooBarTransfer.new(
        failures: [
          Task::Transfer::Failure.new(other.iri, "error", 5.days.ago),
        ],
        created_at: 5.days.ago,
      )
    end

    # failure to multiple recipients
    let(failure_multi_7d) do
      FooBarTransfer.new(
        failures: [
          Task::Transfer::Failure.new(recipient.iri, "error", 7.days.ago),
          Task::Transfer::Failure.new(other.iri, "error", 7.days.ago),
        ],
        created_at: 7.days.ago,
      )
    end

    # success!
    let(success_5d) { FooBarTransfer.new(created_at: 5.days.ago) }
    let(success_now) { FooBarTransfer.new(created_at: 1.hour.ago) }

    context "with no tasks" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [] of FooBarTransfer)).to be_false
      end
    end

    context "with fewer than 3 failures" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_5d, failure_2d])).to be_false
      end
    end

    context "with 3+ failures spanning less than 80 hours" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_3d, failure_2d, failure_1d])).to be_false
      end
    end

    context "with 3+ failures spanning 80+ hours without intermediate success" do
      it "returns true" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_7d, failure_4d, failure_1d])).to be_true
      end
    end

    context "with 3+ failures spanning 80+ hours with intermediate success" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_7d, success_5d, failure_4d, failure_1d])).to be_false
      end
    end

    context "with 3+ failures spanning 80+ hours with recent success" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_7d, failure_4d, failure_1d, success_now])).to be_false
      end
    end

    # a failure to `other` without a failure to `recipient` counts as a success

    context "with 3+ failures spanning 80+ hours with intermediate success" do
      it "returns false" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_7d, failure_other_5d, failure_4d, failure_1d])).to be_false
      end
    end

    context "with failures for multiple recipients" do
      it "returns true" do
        expect(Task::Transfer.is_recipient_down?(recipient.iri, [failure_multi_7d, failure_4d, failure_1d])).to be_true
      end
    end
  end
end
