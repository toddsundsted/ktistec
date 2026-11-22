require "../../../../src/models/task"
require "../../../../src/models/task/mixins/transfer"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"
require "../../../spec_helper/network"

class FooBarTransfer < Task
  include Task::Transfer

  @source_iri = ""
  @subject_iri = ""

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

  # every actor in `delivered` and `failed` is a recipient; each actor
  # in `failed` gets a failure.

  def transfer_factory(delivered = [] of ActivityPub::Actor, failed = [] of ActivityPub::Actor, created_at = Time.utc)
    FooBarTransfer.new(
      recipients: (delivered + failed).map(&.iri),
      failures: failed.map { |actor| Task::Transfer::Failure.new(actor.iri, "failure", created_at) },
      running: false,
      complete: true,
      created_at: created_at,
    )
  end

  def failed_transfer_factory(recipient, created_at = Time.utc)
    transfer_factory(failed: [recipient], created_at: created_at) # ameba:disable Ktistec/NoDirectFactoryCalls
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

  describe "#transfer(activity, from:, to:)" do
    subject { FooBarTransfer.new }

    it "dereferences the recipient" do
      subject.transfer(activity, from: transferer, to: ["https://unknown-recipient/"])
      expect(HTTP::Client.requests).to have("GET https://unknown-recipient/")
    end

    it "stores a message when a remote recipient does not exist" do
      subject.transfer(activity, from: transferer, to: ["https://unknown-recipient/"])
      expect(subject.failures).to have(/recipient does not exist/)
    end

    it "stores a message when a local recipient does not exist" do
      subject.transfer(activity, from: transferer, to: ["https://test.test/actors/missing"])
      expect(subject.failures).to have(/recipient does not exist/)
    end

    it "stores a message when a recipient is bad JSON" do
      subject.transfer(activity, from: transferer, to: ["https://remote/actors/bad-json"])
      expect(subject.failures).to have(/recipient does not exist/)
    end

    it "stores a message when a recipient is not an actor" do
      HTTP::Client.objects["https://remote/objects/note"] = %Q|{"@id":"https://remote/objects/note","@type":"Note"}|
      subject.transfer(activity, from: transferer, to: ["https://remote/objects/note"])
      expect(subject.failures).to have(/recipient does not exist/)
    end

    it "stores a message when a recipient is served with another id" do
      HTTP::Client.actors["https://remote/actors/requested"] = %Q|{"@id":"https://remote/actors/other","@type":"Person"}|
      subject.transfer(activity, from: transferer, to: ["https://remote/actors/requested"])
      expect(subject.failures).to have(/recipient does not exist/)
    end

    it "stores the reason a recipient could not be reached" do
      subject.transfer(activity, from: transferer, to: ["https://unreachable/openssl-error"])
      expect(subject.failures).to have(/Secure connection failure/)
    end

    it "returns a recipient that could not be reached" do
      result = subject.transfer(activity, from: transferer, to: ["https://unreachable/openssl-error"])
      expect(result).to contain_exactly("https://unreachable/openssl-error")
    end

    it "returns a recipient for a transient status" do
      [401, 408, 429, 500, 502, 503, 504].each do |status|
        remote_recipient.assign(inbox: "https://remote/returns-#{status}").save
        result = subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(result).to contain_exactly(remote_recipient.iri), "expected #{status} to be transient"
      end
    end

    it "does not return a recipient for a permanent status" do
      [400, 403, 404, 410, 422].each do |status|
        remote_recipient.assign(inbox: "https://remote/returns-#{status}").save
        result = subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(result).to be_empty, "expected #{status} to be permanent"
      end
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

    context "when the activity's object has been deleted" do
      let_build(:delete, named: :activity, actor_iri: transferer.iri, object_iri: "https://deleted")

      it "serializes and delivers the activity without failing" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(HTTP::Client.requests).to have("POST #{local_recipient.inbox}")
        expect(subject.failures).to be_empty
      end
    end

    context "given an OpenSSL error" do
      before_each do
        # simulate an OpenSSL error
        local_recipient.assign(inbox: "https://remote/openssl-error").save
      end

      it "doesn't raise an error" do
        expect { subject.transfer(activity, from: transferer, to: [local_recipient.iri]) }
          .not_to raise_error(OpenSSL::Error)
      end

      it "stores the failure reason" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(subject.failures).to have(/Secure connection failure: #{local_recipient.inbox}/)
      end

      it "returns the recipient" do
        result = subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(result).to contain_exactly(local_recipient.iri)
      end

      it "does not mark the recipient as down" do
        expect { subject.transfer(activity, from: transferer, to: [local_recipient.iri]) }
          .not_to change { local_recipient.down? }
      end
    end

    context "given an IO error" do
      before_each do
        # simulate an IO error
        local_recipient.assign(inbox: "https://remote/io-error").save
      end

      it "doesn't raise an error" do
        expect { subject.transfer(activity, from: transferer, to: [local_recipient.iri]) }
          .not_to raise_error(IO::Error)
      end

      it "stores the failure reason" do
        subject.transfer(activity, from: transferer, to: [local_recipient.iri])
        expect(subject.failures).to have(/I\/O error: #{local_recipient.inbox}/)
      end

      it "does not mark the recipient as down" do
        expect { subject.transfer(activity, from: transferer, to: [local_recipient.iri]) }
          .not_to change { local_recipient.down? }
      end
    end

    context "given a recipient with a private-address inbox" do
      before_each do
        remote_recipient.assign(inbox: "https://loopback.example/actor/inbox").save
      end

      it "does not post to the inbox" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
      end

      it "records a failure" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(subject.failures).to have(/Request to private address denied/)
      end

      it "does not return the recipient" do
        result = subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(result).to be_empty
      end
    end

    context "given a recipient with a private-address shared inbox" do
      before_each do
        remote_recipient.assign(shared_inbox: "https://loopback.example/shared/inbox").save
      end

      it "does not post to the shared inbox" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.shared_inbox}")
      end

      it "falls back to the inbox" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
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
        expect { subject.transfer(activity, from: transferer, to: [remote_recipient.iri]) }
          .to change { remote_recipient.reload!.down? }.to(true)
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
        expect { subject.transfer(activity, from: transferer, to: [remote_recipient.iri]) }
          .not_to change { remote_recipient.reload!.down? }.from(false)
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
        remote_recipient.assign(shared_inbox: "https://remote/shared/inbox").save
      end

      it "sends the activity to the shared inbox" do
        subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
        expect(HTTP::Client.requests).to have("POST https://remote/shared/inbox")
        expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
      end
    end

    context "given another remote recipient" do
      let_create!(:actor, named: :another_recipient, iri: "https://remote/actors/another")

      context "when multiple recipients share the same shared inbox" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/shared/inbox").save
          another_recipient.assign(shared_inbox: "https://remote/shared/inbox").save
        end

        it "delivers once to the shared inbox" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST https://remote/shared/inbox")
          expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
          expect(HTTP::Client.requests).not_to have("POST #{another_recipient.inbox}")
        end
      end

      context "when delivery to both shared and personal inboxes fail" do
        before_each do
          remote_recipient.assign(inbox: "https://remote/io-error", shared_inbox: "https://remote/openssl-error").save
          another_recipient.assign(inbox: "https://remote/io-error", shared_inbox: "https://remote/openssl-error").save
        end

        it "tracks failures for each recipient" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(subject.failures.map(&.recipient)).to contain_exactly(remote_recipient.iri, another_recipient.iri)
        end
      end

      context "when there are no shared inboxes and delivery to personal inboxes fail" do
        before_each do
          remote_recipient.assign(inbox: "https://remote/openssl-error", shared_inbox: nil).save
          another_recipient.assign(inbox: "https://remote/openssl-error", shared_inbox: nil).save
        end

        it "tracks failures for each recipient" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(subject.failures.map(&.recipient)).to contain_exactly(remote_recipient.iri, another_recipient.iri)
        end
      end

      context "when mixing recipients with and without a shared inbox" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/shared/inbox").save
        end

        it "delivers to shared and individual inboxes appropriately" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST https://remote/shared/inbox")
          expect(HTTP::Client.requests).to have("POST #{another_recipient.inbox}")
          expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
        end
      end

      context "when shared inbox delivery fails" do
        before_each do
          remote_recipient.assign(shared_inbox: "https://remote/openssl-error").save
          another_recipient.assign(shared_inbox: "https://remote/openssl-error").save
        end

        it "attempts delivery to the shared inbox" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST https://remote/openssl-error")
        end

        it "falls back to personal inboxes" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
          expect(HTTP::Client.requests).to have("POST #{another_recipient.inbox}")
        end

        it "does not record failures" do
          subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(subject.failures).to be_empty
        end

        it "does not return the recipients" do
          result = subject.transfer(activity, from: transferer, to: [remote_recipient.iri, another_recipient.iri])
          expect(result).to be_empty
        end

        context "and the personal inbox is the shared inbox" do
          before_each do
            remote_recipient.assign(inbox: "https://remote/openssl-error", shared_inbox: "https://remote/openssl-error").save
          end

          it "attempts delivery the inbox" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            expect(HTTP::Client.requests).to have("POST https://remote/openssl-error")
          end

          it "does not attempt delivery twice" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            posts = HTTP::Client.requests.select { |r| r.method == "POST" }
            expect(posts.size).to eq(1)
          end

          it "records failure" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            expect(subject.failures.map(&.recipient)).to contain_exactly(remote_recipient.iri)
          end
        end

        context "and personal inbox also fails" do
          before_each do
            remote_recipient.assign(inbox: "https://remote/io-error", shared_inbox: "https://remote/openssl-error").save
          end

          it "attempts delivery to shared inbox" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            expect(HTTP::Client.requests).to have("POST https://remote/openssl-error")
          end

          it "attempts delivery to personal inbox" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            expect(HTTP::Client.requests).to have("POST https://remote/io-error")
          end

          it "records failure" do
            subject.transfer(activity, from: transferer, to: [remote_recipient.iri])
            expect(subject.failures.map(&.recipient)).to contain_exactly(remote_recipient.iri)
          end
        end
      end
    end
  end

  describe "#transfer(activity, from:)" do
    let_create!(:actor, named: :permanent_recipient, iri: "https://remote/actors/permanent")
    let_create!(:actor, named: :transient_recipient, iri: "https://remote/actors/transient")

    subject { FooBarTransfer.new(recipients: [transient_recipient.iri, permanent_recipient.iri]) }

    def run
      subject.transfer(activity, from: transferer)
    end

    context "given a recipient that fails permanently" do
      before_each { permanent_recipient.assign(inbox: "https://remote/returns-404").save }

      it "does not schedule a retry" do
        expect { run }.not_to change { subject.next_attempt_at }.from(nil)
      end

      context "and a recipient that fails transiently" do
        before_each { transient_recipient.assign(inbox: "https://remote/returns-503").save }

        context "after the first attempt" do
          before_each { run }

          it "schedules a retry in five minutes" do
            expect(subject.next_attempt_at).to be_close(5.minutes.from_now, delta: 10.seconds)
          end

          context "after the first retry" do
            before_each do
              HTTP::Client.requests.clear
              run
            end

            it "retries only the recipient that failed transiently" do
              expect(HTTP::Client.requests).to have("POST #{transient_recipient.inbox}")
              expect(HTTP::Client.requests).not_to have("POST #{permanent_recipient.inbox}")
            end

            it "schedules the next retry in ten minutes" do
              expect(subject.next_attempt_at).to be_close(10.minutes.from_now, delta: 20.seconds)
            end

            context "after the fifth retry" do
              before_each { 4.times { run } }

              it "schedules a retry in 160 minutes" do
                expect(subject.next_attempt_at).to be_close(160.minutes.from_now, delta: 5.minutes)
              end

              it "gives up after the sixth retry" do
                expect { run }.not_to change { subject.next_attempt_at }
              end
            end
          end

          context "after a retry that succeeds" do
            before_each do
              transient_recipient.assign(inbox: "https://remote/actors/transient/inbox").save
              run
            end

            it "clears the failures of the recipient that succeeded" do
              expect(subject.failures.map(&.recipient)).not_to contain(transient_recipient.iri)
            end

            it "keeps the failures of the recipient that failed permanently" do
              expect(subject.failures.map(&.recipient)).to contain(permanent_recipient.iri)
            end
          end
        end

        context "and earlier failures for the permanent recipient spanning days" do
          let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 7.days.ago)
          let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 4.days.ago)
          let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 1.day.ago)

          context "after the first attempt" do
            before_each { run }

            it "marks the permanent recipient down" do
              expect(permanent_recipient.reload!.down?).to be_true
            end
          end
        end

        context "and earlier failures for the transient recipient spanning days" do
          let_create!(:failed_transfer, named: nil, recipient: transient_recipient, created_at: 7.days.ago)
          let_create!(:failed_transfer, named: nil, recipient: transient_recipient, created_at: 4.days.ago)
          let_create!(:failed_transfer, named: nil, recipient: transient_recipient, created_at: 1.day.ago)

          context "after the first attempt" do
            before_each { run }

            it "does not mark the recipient down" do
              expect(transient_recipient.reload!.down?).to be_false
            end

            context "after the last retry" do
              before_each { 6.times { run } }

              it "marks the recipient down" do
                expect(transient_recipient.reload!.down?).to be_true
              end
            end
          end
        end
      end

      context "and earlier failures for the permanent recipient spanning days" do
        let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 7.days.ago)
        let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 4.days.ago)
        let_create!(:failed_transfer, named: nil, recipient: permanent_recipient, created_at: 1.day.ago)

        context "after the first attempt" do
          before_each { run }

          it "marks the recipient down" do
            expect(permanent_recipient.reload!.down?).to be_true
          end
        end
      end
    end
  end

  describe ".recipient_down?" do
    let_build(:actor, named: :recipient, iri: "https://remote/recipient")

    # failures at various time points
    let_build(:failed_transfer, named: :failure_7d, recipient: recipient, created_at: 7.days.ago)
    let_build(:failed_transfer, named: :failure_5d, recipient: recipient, created_at: 5.days.ago)
    let_build(:failed_transfer, named: :failure_4d, recipient: recipient, created_at: 4.days.ago)
    let_build(:failed_transfer, named: :failure_3d, recipient: recipient, created_at: 3.days.ago)
    let_build(:failed_transfer, named: :failure_2d, recipient: recipient, created_at: 2.days.ago)
    let_build(:failed_transfer, named: :failure_1d, recipient: recipient, created_at: 1.day.ago)

    let_build(:actor, named: :other, iri: "https://remote/other")

    # delivered to recipient, failed for other
    let_build(:transfer, named: :failure_other_5d, delivered: [recipient], failed: [other], created_at: 5.days.ago)

    # failed for recipient and other
    let_build(:transfer, named: :failure_multi_7d, failed: [recipient, other], created_at: 7.days.ago)

    # delivered to recipient
    let_build(:transfer, named: :success_5d, delivered: [recipient], created_at: 5.days.ago)
    let_build(:transfer, named: :success_now, delivered: [recipient], created_at: 1.hour.ago)

    context "with no tasks" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [] of FooBarTransfer)).to be_false
      end
    end

    context "with fewer than 3 failures" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_5d, failure_2d])).to be_false
      end
    end

    context "with 3+ failures spanning less than 80 hours" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_3d, failure_2d, failure_1d])).to be_false
      end
    end

    context "with 3+ failures spanning 80+ hours without intermediate success" do
      it "returns true" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_7d, failure_4d, failure_1d])).to be_true
      end
    end

    context "with 3+ failures spanning 80+ hours with intermediate success" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_7d, success_5d, failure_4d, failure_1d])).to be_false
      end
    end

    context "with 3+ failures spanning 80+ hours with recent success" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_7d, failure_4d, failure_1d, success_now])).to be_false
      end
    end

    # a failure to `other` without a failure to `recipient` counts as a success

    context "with 3+ failures spanning 80+ hours with intermediate success" do
      it "returns false" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_7d, failure_other_5d, failure_4d, failure_1d])).to be_false
      end
    end

    context "with failures for multiple recipients" do
      it "returns true" do
        expect(Task::Transfer.recipient_down?(recipient.iri, [failure_multi_7d, failure_4d, failure_1d])).to be_true
      end
    end
  end
end
