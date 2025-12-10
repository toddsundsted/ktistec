require "../object"
require "./note"
require "../../poll"

class ActivityPub::Object
  class Question < ActivityPub::Object
    has_one poll, foreign_key: question_iri, primary_key: iri, inverse_of: question

    def voted_by?(actor : ActivityPub::Actor) : Bool
      !ActivityPub::Object.where(
        "type = '#{ActivityPub::Object::Note}' AND in_reply_to_iri = ? AND attributed_to_iri = ? AND name IS NOT NULL",
        self.iri,
        actor.iri
      ).empty?
    end

    def votes_by(actor : ActivityPub::Actor) : Array(ActivityPub::Object)
      ActivityPub::Object.where(
        "type = '#{ActivityPub::Object::Note}' AND in_reply_to_iri = ? AND attributed_to_iri = ? AND name IS NOT NULL",
        self.iri,
        actor.iri
      )
    end

    def options_by(actor : ActivityPub::Actor) : Array(String)
      votes_by(actor).compact_map(&.name)
    end

    def self.map(json, **options)
      json = json.is_a?(String | IO) ? Ktistec::JSON_LD.expand(JSON.parse(json)) : json

      one_of = json.dig?("https://www.w3.org/ns/activitystreams#oneOf")
      any_of = json.dig?("https://www.w3.org/ns/activitystreams#anyOf")

      multiple_choice = !!any_of

      poll_options =
        if one_of || any_of
          Ktistec::JSON_LD.dig_values?(json, multiple_choice ? "https://www.w3.org/ns/activitystreams#anyOf" : "https://www.w3.org/ns/activitystreams#oneOf") do |option|
            name = Ktistec::JSON_LD.dig?(option, "https://www.w3.org/ns/activitystreams#name", "und")
            votes_count = option.dig?("https://www.w3.org/ns/activitystreams#replies", "https://www.w3.org/ns/activitystreams#totalItems").try(&.as_i) || 0
            Poll::Option.new(name, votes_count) if name
          end
        end || [] of Poll::Option

      super(json, **options).merge({
        "poll" => Poll.new(
          options: poll_options,
          multiple_choice: multiple_choice,
          voters_count: json.dig?("http://joinmastodon.org/ns#votersCount").try(&.as_i),
          closed_at: parse_closed_at(json),
        ),
      })
    end

    private def self.parse_closed_at(json)
      if (closed = json["http://joinmastodon.org/ns#closed"]?)
        if (closed_str = closed.as_s?)
          Time.parse_rfc3339(closed_str)
        else
          Time.utc
        end
      elsif (end_time = Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#endTime"))
        Time.parse_rfc3339(end_time)
      end
    rescue Time::Format::Error
    end
  end
end
