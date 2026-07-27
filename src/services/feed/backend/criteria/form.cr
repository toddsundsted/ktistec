require "json"

require "../criteria"

class Feed
  abstract class Backend
    class Criteria < Backend
      # Translates between the criteria backend's type-grouped
      # `params` and three any/all/none buckets.
      #
      # `parse` and `format` are inverses over the params `parse`
      # produces -- i.e. every feed the form creates.
      #
      # Note: the order is presentation only.
      #
      module Form
        TYPES = {"keywords" => "keyword", "hashtags" => "hashtag", "mentions" => "mention"}

        # Parses the three form buckets into the backend's `params`.
        #
        def self.parse(any : String, all : String, none : String) : Hash(String, JSON::Any)
          collected = {} of String => Hash(String, Array(String))
          ordered = {} of String => Array(String)
          {"any" => any, "all" => all, "none" => none}.each do |selector, text|
            text.gsub("\r\n", "\n").split('\n').each do |line|
              next if line.blank?
              group, term = classify(line)
              ((collected[group] ||= {} of String => Array(String))[selector] ||= [] of String) << term
              (ordered[selector] ||= [] of String) << present(group, term)
            end
          end
          params = {} of String => JSON::Any
          TYPES.each_key do |group|
            next unless (selectors = collected[group]?)
            hash = {} of String => JSON::Any
            SELECTORS.each do |selector|
              next unless (terms = selectors[selector]?)
              hash[selector] = JSON::Any.new(terms.map { |term| JSON::Any.new(term) })
            end
            params[group] = JSON::Any.new(hash)
          end
          unless ordered.empty?
            hash = {} of String => JSON::Any
            SELECTORS.each do |selector|
              next unless (lines = ordered[selector]?)
              hash[selector] = JSON::Any.new(lines.map { |line| JSON::Any.new(line) })
            end
            params[ORDER] = JSON::Any.new(hash)
          end
          params
        end

        # Formats `params` as the three form buckets.
        #
        def self.format(params : Hash(String, JSON::Any)) : NamedTuple(any: String, all: String, none: String)
          buckets = display_entries(params).transform_values do |entries|
            entries.map { |(group, term)| present(group, term) }.join('\n')
          end
          {any: buckets["any"], all: buckets["all"], none: buckets["none"]}
        end

        # A single typed term.
        #
        record Term, type : String, value : String do
          # The value prefixed with its type's sigil.
          #
          def label : String
            Criteria::GROUPS.find(&.label.==(type)).try(&.present(value)) || value
          end
        end

        # The any/all/none typed-term projection and a term count.
        #
        record Summary,
          any : Array(Term),
          all : Array(Term),
          none : Array(Term),
          count : Int32

        # Projects `params` into typed terms per selector and a total
        # term count.
        #
        def self.summarize(params : Hash(String, JSON::Any)) : Summary
          entries = display_entries(params)
          terms = {} of String => Array(Term)
          count = 0
          SELECTORS.each do |selector|
            terms[selector] = entries[selector].map do |(group, term)|
              count += 1
              Term.new(TYPES[group], term)
            end
          end
          Summary.new(any: terms["any"], all: terms["all"], none: terms["none"], count: count)
        end

        # Infers a line's group and extracts its term.
        #
        private def self.classify(line : String) : {String, String}
          case line[0]?
          when '#'
            {"hashtags", line[1..]}
          when '@'
            {"mentions", line[1..]}
          else
            Criteria.iri_term?(line) ? {"mentions", line} : {"keywords", line}
          end
        end

        # Prefixes a stored term with its group's sigil for display.
        #
        private def self.present(group : String, term : String) : String
          Term.new(TYPES[group], term).label
        end

        # The entries to display, per selector -- in the order they
        # were entered when that order was recorded; grouped by type
        # otherwise.
        #
        private def self.display_entries(params : Hash(String, JSON::Any)) : Hash(String, Array({String, String}))
          grouped = grouped_entries(params)
          entry_order(params, grouped) || grouped
        end

        # Every `(group, term)` in `params`, per selector, grouped by
        # type.
        #
        private def self.grouped_entries(params : Hash(String, JSON::Any)) : Hash(String, Array({String, String}))
          entries = {"any" => [] of {String, String}, "all" => [] of {String, String}, "none" => [] of {String, String}}
          each_term(params) do |group, selector, term|
            entries[selector] << {group, term}
          end
          entries
        end

        # Every entry, permuted into the order they were entered.
        #
        private def self.entry_order(params : Hash(String, JSON::Any), grouped : Hash(String, Array({String, String}))) : Hash(String, Array({String, String}))?
          return unless (raw = params[ORDER]?.try(&.as_h?))
          ordered = {} of String => Array({String, String})
          SELECTORS.each do |selector|
            remaining = grouped[selector].dup
            entries = [] of {String, String}
            (raw[selector]?.try(&.as_a?) || [] of JSON::Any).each do |value|
              return unless (line = value.as_s?)
              return unless (index = remaining.index { |(group, term)| present(group, term) == line })
              entries << remaining.delete_at(index)
            end
            return unless remaining.empty?
            ordered[selector] = entries
          end
          ordered
        end

        # Yields every `(group, selector, term)` in `params`.
        #
        # Groups in display order and selectors in any/all/none order.
        #
        private def self.each_term(params : Hash(String, JSON::Any), &)
          TYPES.each_key do |group|
            next unless (selectors = params[group]?.try(&.as_h?))
            SELECTORS.each do |selector|
              next unless (list = selectors[selector]?.try(&.as_a?))
              list.each do |value|
                next unless (term = value.as_s?)
                yield group, selector, term
              end
            end
          end
        end
      end
    end
  end
end
