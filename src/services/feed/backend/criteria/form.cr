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
      module Form
        TYPES = {"keywords" => "keyword", "hashtags" => "hashtag", "mentions" => "mention"}

        # Parses the three form buckets into the backend's `params`.
        #
        def self.parse(any : String, all : String, none : String) : Hash(String, JSON::Any)
          collected = {} of String => Hash(String, Array(String))
          {"any" => any, "all" => all, "none" => none}.each do |selector, text|
            text.gsub("\r\n", "\n").split('\n').each do |line|
              next if line.blank?
              group, term = classify(line)
              ((collected[group] ||= {} of String => Array(String))[selector] ||= [] of String) << term
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
          params
        end

        # Formats `params` as the three form buckets.
        #
        def self.format(params : Hash(String, JSON::Any)) : NamedTuple(any: String, all: String, none: String)
          buckets = {"any" => [] of String, "all" => [] of String, "none" => [] of String}
          each_term(params) do |group, selector, term|
            buckets[selector] << present(group, term)
          end
          {any: buckets["any"].join('\n'), all: buckets["all"].join('\n'), none: buckets["none"].join('\n')}
        end

        # A single typed term.
        #
        record Chip, type : String, term : String

        # The any/all/none typed-chip projection and a term count.
        #
        record Summary,
          any : Array(Chip),
          all : Array(Chip),
          none : Array(Chip),
          count : Int32

        # Projects `params` into typed chips per selector and a total
        # term count.
        #
        def self.summarize(params : Hash(String, JSON::Any)) : Summary
          chips = {"any" => [] of Chip, "all" => [] of Chip, "none" => [] of Chip}
          count = 0
          each_term(params) do |group, selector, term|
            chips[selector] << Chip.new(TYPES[group], term)
            count += 1
          end
          Summary.new(any: chips["any"], all: chips["all"], none: chips["none"], count: count)
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
          case group
          when "hashtags" then "##{term}"
          when "mentions" then Criteria.iri_term?(term) ? term : "@#{term}"
          else                 term
          end
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
