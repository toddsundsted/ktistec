require "../backend"
require "../../../framework/util"

class Feed
  abstract class Backend
    # A criteria judge.
    #
    # An object is judged against structured criteria carried in the
    # feed's `params`. Criteria are organized into groups (only
    # `keywords` for now); each group carries `any`/`all`/`none` term
    # lists. A post is *in* when the group matches its positive terms
    # -- at least one `any` term and every `all` term -- and no `none`
    # term matches; exclusion always wins. Matching is
    # case-insensitive substring over the object's HTML-stripped
    # content and summary and its plain-text name.
    #
    class Criteria < Backend
      GROUPS    = %w(keywords)
      SELECTORS = %w(any all none)
      POSITIVE  = %w(any all)

      def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
        group = feed.params["keywords"]?.try(&.as_h?) || {} of String => JSON::Any
        any = terms(group, "any")
        all = terms(group, "all")
        none = terms(group, "none")
        objects.map do |object|
          text = searchable_text(object)
          excluded = none.select { |term| text.includes?(term.downcase) }
          matched = any.select { |term| text.includes?(term.downcase) }
          if !excluded.empty?
            Judgment.new(included: false, reason: "excluded: #{excluded.join(", ")}")
          elsif positive?(text, any, all, matched)
            Judgment.new(included: true, reason: "matched: #{(matched + all).uniq.join(", ")}")
          else
            Judgment.new(included: false, reason: "no match")
          end
        end
      end

      def validate_params(params : Hash(String, JSON::Any)) : Array(String)
        errors = [] of String
        unknown_groups = params.keys - GROUPS
        errors << "unknown groups: #{unknown_groups.join(", ")}" unless unknown_groups.empty?
        positive_terms = 0
        if (keywords = params["keywords"]?)
          if (group = keywords.as_h?)
            unknown_selectors = group.keys - SELECTORS
            errors << "keywords has unknown selectors: #{unknown_selectors.join(", ")}" unless unknown_selectors.empty?
            SELECTORS.each do |selector|
              next unless (list = group[selector]?)
              if (array = list.as_a?) && array.all?(&.as_s?.try(&.presence))
                positive_terms += array.size if selector.in?(POSITIVE)
              else
                errors << "keywords #{selector} must be an array of non-blank strings"
              end
            end
          else
            errors << "keywords must be an object with any, all, or none"
          end
        end
        errors << "at least one any or all term is required" if positive_terms.zero?
        errors
      end

      # Returns a group's non-blank string terms for a selector.
      #
      private def terms(group : Hash(String, JSON::Any), selector : String) : Array(String)
        group[selector]?.try(&.as_a?).try(&.compact_map(&.as_s?.try(&.presence))) || [] of String
      end

      # A post matches positively when it carries at least one positive
      # term and satisfies `any` and `all`.
      #
      private def positive?(text, any, all, matched) : Bool
        return false if any.empty? && all.empty?
        (any.empty? || !matched.empty?) && all.all? { |term| text.includes?(term.downcase) }
      end

      # Concatenates the object's searchable text.
      #
      private def searchable_text(object : ActivityPub::Object) : String
        content = Ktistec::Util.render_as_text(object.content)
        summary = Ktistec::Util.render_as_text(object.summary)
        "#{content} #{summary} #{object.name}".downcase
      end
    end

    register "criteria", Criteria.new
  end
end
