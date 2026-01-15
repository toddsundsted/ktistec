require "./builder_base"
require "../../models/activity_pub/object/question"
require "../../models/poll"

module ObjectBuilder
  # Builds `Question` objects from request parameters.
  #
  class QuestionBuilder < BuilderBase
    def build(
      params : Hash(String, String | Array(String)),
      actor : ActivityPub::Actor,
      object : ActivityPub::Object? = nil,
    ) : BuildResult
      iri = "#{Ktistec.host}/objects/#{Ktistec::Util.id}"
      question = (object || ActivityPub::Object::Question.new(iri: iri)).as(ActivityPub::Object::Question)
      result = BuildResult.new(question)

      in_reply_to_iri = extract_string(params, "in-reply-to")
      in_reply_to = validate_reply_to(in_reply_to_iri, result)
      addressing = calculate_addressing(params, actor, in_reply_to)
      apply_common_attributes(params, addressing, question, actor, in_reply_to)

      poll_options = extract_array(params, "poll-options")
      poll_duration = extract_integer(params, "poll-duration")
      poll_multiple_choice = extract_boolean(params, "poll-multiple-choice")

      unless question.poll? && poll_options.nil?
        validate_poll_changes(question, poll_options, poll_duration, poll_multiple_choice, result)

        closed_at = poll_duration ? Time.unix(poll_duration) : nil
        question.poll = build_poll(question, poll_options, closed_at, poll_multiple_choice)
      end

      collect_model_errors(question, result)

      result
    end

    # Prevents editing poll settings after publishing.
    #
    # Published polls are immutable.
    #
    private def validate_poll_changes(
      question : ActivityPub::Object::Question,
      new_options : Array(String)?,
      new_duration : Int32?,
      new_multiple_choice : Bool,
      result : BuildResult,
    )
      if (poll = question.poll?) && !question.draft?
        if new_options && new_options != poll.options.map(&.name)
          result.add_error("poll_options", "cannot be changed after publishing")
        end
        if new_duration
          result.add_error("poll_duration", "cannot be changed after publishing")
        end
        if new_multiple_choice != poll.multiple_choice
          result.add_error("poll_multiple_choice", "cannot be changed after publishing")
        end
      end
    end

    # Builds `Poll` objects.
    #
    private def build_poll(
      question : ActivityPub::Object::Question,
      options : Array(String)?,
      closed_at : Time?,
      multiple_choice : Bool,
    ) : Poll
      poll = question.poll? || Poll.new(question: question)
      poll.assign(
        options: (options || [] of String).map do |option|
          Poll::Option.new(
            name: option.strip,
            votes_count: 0,
          )
        end,
        multiple_choice: multiple_choice,
        closed_at: closed_at,
        voters_count: 0,
      )
    end
  end
end
