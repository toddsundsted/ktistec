require "../backend"
require "../../../framework/util"

class Feed
  abstract class Backend
    # A keyword judge.
    #
    # An object is in when at least `threshold` (default 1) of the
    # feed's `keywords` occur in its content text. Matching is
    # case-insensitive over the HTML-stripped content, and matches
    # bare substrings, not words.
    #
    class Keyword < Backend
      def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
        keywords = feed.params["keywords"].as_a.map(&.as_s)
        threshold = feed.params["threshold"]?.try(&.as_i) || 1
        objects.map do |object|
          text = Ktistec::Util.render_as_text(object.content).downcase
          matched = keywords.select { |keyword| text.includes?(keyword.downcase) }
          if matched.size >= threshold
            Judgment.new(included: true, reason: "matched: #{matched.join(", ")}")
          else
            Judgment.new(included: false, reason: "matched #{matched.size} of #{threshold} keywords")
          end
        end
      end

      def validate_params(params : Hash(String, JSON::Any)) : Array(String)
        errors = [] of String
        keywords = params["keywords"]?.try(&.as_a?)
        # a blank keyword matches every object, so blank is invalid
        if keywords.nil? || keywords.empty? || !keywords.all?(&.as_s?.try(&.presence))
          errors << "keywords must be a non-empty array of non-blank strings"
        end
        if (threshold = params["threshold"]?)
          if (value = threshold.as_i?).nil? || value < 1
            errors << "threshold must be a positive integer"
          elsif keywords && value > keywords.size
            errors << "threshold must not exceed the number of keywords"
          end
        end
        errors
      end
    end

    register "keyword", Keyword.new
  end
end
