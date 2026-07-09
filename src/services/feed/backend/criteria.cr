require "../backend"
require "../../../framework/util"

class Feed
  abstract class Backend
    # A criteria judge.
    #
    # An object is judged against structured criteria carried in the
    # feed's `params`, organized into groups: `keywords` (matched by
    # case-insensitive substring over the object's HTML-stripped
    # content and summary and its plain-text name) and `hashtags`
    # (matched by exact, case-insensitive equality against the
    # object's hashtag names) and `mentions` (matched by qualified,
    # case-insensitive handle or by actor IRI). Each group carries
    # `any`/`all`/`none` term lists. Terms are evaluated together: an
    # object is in when at least one positive term matches (and every
    # `all` term matches) and no `none` term matches. Exclusion always
    # wins, across groups.
    #
    class Criteria < Backend
      SELECTORS = %w(any all none)
      POSITIVE  = %w(any all)

      # Distinguishes an IRI term from a handle.
      #
      def self.iri_term?(term : String) : Bool
        term.starts_with?(/https?:\/\//i)
      end

      def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment)
        active = active_groups(feed.params)
        objects.map { |object| judge_one(object, active) }
      end

      def validate_params(params : Hash(String, JSON::Any)) : Array(String)
        errors = [] of String
        unknown_groups = params.keys - GROUPS.map(&.key)
        errors << "unknown groups: #{unknown_groups.join(", ")}" unless unknown_groups.empty?
        positive_terms = 0
        GROUPS.each do |group|
          next unless (value = params[group.key]?)
          unless (raw = value.as_h?)
            errors << "#{group.key} must be an object with any, all, or none"
            next
          end
          unknown_selectors = raw.keys - SELECTORS
          errors << "#{group.key} has unknown selectors: #{unknown_selectors.join(", ")}" unless unknown_selectors.empty?
          SELECTORS.each do |selector|
            next unless (list = raw[selector]?)
            if (array = list.as_a?) && array.all? { |element| element.as_s?.try(&.presence).try { |string| group.normalize(string).presence } }
              positive_terms += array.size if selector.in?(POSITIVE)
            else
              errors << "#{group.key} #{selector} must be an array of non-blank strings"
            end
          end
        end
        errors << "at least one any or all term is required" if positive_terms.zero?
        errors
      end

      private record Active,
        group : Group,
        any : Array(String),
        all : Array(String),
        none : Array(String)

      # Returns the active groups -- those present in `params` with at
      # least one term.
      #
      private def active_groups(params : Hash(String, JSON::Any)) : Array(Active)
        GROUPS.compact_map do |group|
          next unless (raw = params[group.key]?.try(&.as_h?))
          any = group.terms(raw, "any")
          all = group.terms(raw, "all")
          none = group.terms(raw, "none")
          next if any.empty? && all.empty? && none.empty?
          Active.new(group, any, all, none)
        end
      end

      # Judges a single object against the active groups.
      #
      # Pools every term across the groups -- each matched by its own
      # group -- and applies the shared combinator: exclusion wins,
      # then at least one positive term must match (with every `all`
      # term matching).
      #
      private def judge_one(object : ActivityPub::Object, active : Array(Active)) : Judgment
        excluded = [] of String
        matched = [] of String
        required = [] of String
        any_present = false
        positive_present = false
        all_ok = true
        active.each do |entry|
          matches = entry.group.matcher_for(object)
          any_present ||= !entry.any.empty?
          positive_present ||= !(entry.any.empty? && entry.all.empty?)
          entry.none.each { |term| excluded << entry.group.label_for(term) if matches.call(term) }
          entry.any.each { |term| matched << entry.group.label_for(term) if matches.call(term) }
          entry.all.each do |term|
            required << entry.group.label_for(term)
            all_ok = false unless matches.call(term)
          end
        end
        if !excluded.empty?
          Judgment.new(included: false, reason: "excluded: #{excluded.join(", ")}")
        elsif positive_present && (!any_present || !matched.empty?) && all_ok
          Judgment.new(included: true, reason: "matched: #{(matched + required).uniq.join(", ")}")
        else
          Judgment.new(included: false, reason: "no match")
        end
      end

      # A criterion group: parses its term lists from `params` and
      # decides whether a term matches an object.
      #
      private abstract class Group
        # The group's key in `params`.
        #
        abstract def key : String

        # The label naming the group in a verdict reason.
        #
        abstract def label : String

        # Normalizes a raw term into its matchable form.
        #
        abstract def normalize(term : String) : String

        # Returns a predicate matching a normalized term against the
        # object, computing any per-object state once.
        #
        abstract def matcher_for(object : ActivityPub::Object) : String -> Bool

        # Returns the group's non-blank, normalized terms for a
        # selector.
        #
        def terms(raw : Hash(String, JSON::Any), selector : String) : Array(String)
          list = raw[selector]?.try(&.as_a?)
          return [] of String unless list
          list.compact_map do |value|
            if (string = value.as_s?.try(&.presence))
              normalize(string)
            end
          end
        end

        # Labels a term with its group for a verdict reason.
        #
        def label_for(term : String) : String
          "#{term} [#{label}]"
        end
      end

      # Matches keywords by case-insensitive substring over the
      # object's content, summary, and name.
      #
      private class Keywords < Group
        def key : String
          "keywords"
        end

        def label : String
          "keyword"
        end

        def normalize(term : String) : String
          term.downcase
        end

        def matcher_for(object : ActivityPub::Object) : String -> Bool
          content = Ktistec::Util.render_as_text(object.content)
          summary = Ktistec::Util.render_as_text(object.summary)
          text = "#{content} #{summary} #{object.name}".downcase
          ->(term : String) { text.includes?(term) }
        end
      end

      # Matches hashtags by exact, case-insensitive equality against
      # the object's hashtag names, with a leading `#` normalized away.
      #
      private class Hashtags < Group
        def key : String
          "hashtags"
        end

        def label : String
          "hashtag"
        end

        def normalize(term : String) : String
          term.lstrip('#').downcase
        end

        def matcher_for(object : ActivityPub::Object) : String -> Bool
          names = object.hashtags.map { |hashtag| normalize(hashtag.name) }
          ->(term : String) { names.includes?(term) }
        end
      end

      # Matches mentions by case-insensitive, qualified handle or by
      # actor IRI, against the object's mention names and hrefs.
      #
      private class Mentions < Group
        def key : String
          "mentions"
        end

        def label : String
          "mention"
        end

        def normalize(term : String) : String
          if Criteria.iri_term?(term)
            normalize_iri(term)
          else
            normalize_handle(term)
          end
        end

        def matcher_for(object : ActivityPub::Object) : String -> Bool
          identifiers = [] of String
          object.mentions.each do |mention|
            identifiers << normalize_handle(mention.name)
            if (href = mention.href)
              identifiers << normalize_iri(href)
            end
          end
          ->(term : String) { identifiers.includes?(term) }
        end

        private def normalize_handle(handle : String) : String
          handle = handle.lstrip('@').downcase
          local, at, host = handle.rpartition('@')
          return handle if at.empty?
          "#{local}@#{host.partition(':').first}"
        end

        private def normalize_iri(iri : String) : String
          iri.downcase
        end
      end

      GROUPS = [Keywords.new, Hashtags.new, Mentions.new] of Group
    end

    register "criteria", Criteria.new
  end
end
