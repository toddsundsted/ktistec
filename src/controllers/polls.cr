require "../framework/controller"
require "../services/outbox_activity_processor"
require "../models/activity_pub/object/question"
require "../models/activity_pub/object/note"
require "../models/poll"

class PollsController
  include Ktistec::Controller

  post "/polls/:id/vote" do |env|
    unless (poll = Poll.find?(id_param(env)))
      not_found
    end

    if poll.expired?
      unprocessable_entity "Poll has expired"
    end

    selected_options =
      if accepts?("text/html")
        env.params.body.fetch_all("options[]")
      else
        options = env.params.json["options"]?
        if options.is_a?(Array)
          options.map(&.as_s)
        else
          [] of String
        end
      end

    if selected_options.empty?
      unprocessable_entity "At least one option must be selected"
    end

    invalid_options = selected_options - poll.options.map(&.name)
    unless invalid_options.empty?
      unprocessable_entity "Invalid options: #{invalid_options.join(", ")}"
    end

    unless poll.multiple_choice
      if selected_options.size > 1
        unprocessable_entity "Poll only allows one selection"
      end
    end

    actor = env.account.actor
    question = poll.question

    if question.voted_by?(actor)
      unprocessable_entity("Poll does not allow multiple votes")
    end

    now = Time.utc

    selected_options.each do |name|
      vote = ActivityPub::Object::Note.new(
        iri: "#{host}/objects/#{id}",
        attributed_to: actor,
        in_reply_to: question,
        name: name,
        content: nil,
        published: now,
        to: [question.attributed_to.iri],
        cc: [] of String,
      )
      activity = ActivityPub::Activity::Create.new(
        iri: "#{host}/activities/#{id}",
        actor: actor,
        object: vote,
        published: vote.published,
        to: vote.to,
        cc: vote.cc,
      ).save

      OutboxActivityProcessor.process(env.account, activity)
    end

    redirect back_path
  end
end
