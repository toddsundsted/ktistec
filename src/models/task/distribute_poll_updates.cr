require "../task"
require "../poll"
require "../account"
require "../activity_pub/object/question"
require "../activity_pub/activity/update"
require "../../services/outbox_activity_processor"

class Task
  class DistributePollUpdates < Task
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(actor) { "missing: #{source_iri}" unless actor? }

    belongs_to question, class_name: ActivityPub::Object::Question, foreign_key: subject_iri, primary_key: iri
    validates(question) { "missing: #{subject_iri}" unless question? }

    CHECK_INTERVAL = 10.minutes

    def perform
      if question.local?
        begin
          distribute_update
        ensure
          unless question.poll.expired?
            self.next_attempt_at = randomized_next_attempt_at(CHECK_INTERVAL)
          end
        end
      end
    end

    private def distribute_update
      current_voters_count = question.voters.size
      current_tallies = question.votes.reduce(Hash(String, Int32).new(0)) do |tallies, vote|
        if (name = vote.name)
          tallies[name] += 1
        end
        tallies
      end

      if count_or_tallies_changed?(current_voters_count, current_tallies)
        update_count_and_tallies(current_voters_count, current_tallies)
        question.assign(updated: Time.utc).save
        send_update
      end
    end

    private def count_or_tallies_changed?(current_voters_count, current_tallies) : Bool
      poll = question.poll

      (current_voters_count != poll.voters_count) ||
        poll.options.any? do |option|
          current_count = current_tallies[option.name]? || 0
          current_count != option.votes_count
        end
    end

    private def update_count_and_tallies(current_voters_count, current_tallies)
      poll = question.poll

      updated_options = poll.options.map do |option|
        new_count = current_tallies[option.name]? || 0
        Poll::Option.new(option.name, new_count)
      end

      poll.assign(
        voters_count: current_voters_count,
        options: updated_options,
      ).save
    end

    private def send_update
      actor = question.attributed_to

      account = Account.find(actor: actor)

      activity = ActivityPub::Activity::Update.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: actor,
        object: question,
        published: Time.utc,
        to: recipients_to,
        cc: recipients_cc,
      ).save

      OutboxActivityProcessor.process(account, activity)
    end

    private def recipients_to : Array(String)
      original_to = question.to || [] of String
      voter_iris = question.voters.map(&.iri)

      (original_to + voter_iris).uniq
    end

    private def recipients_cc : Array(String)
      question.cc || [] of String
    end

    def path_to
      Ktistec::ViewHelper.remote_object_path(question)
    end
  end
end
