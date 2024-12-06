require "../../../framework/model"

module Ktistec
  module Model
    module Serialized
      macro included
        extend ClassMethods
      end

      module ClassMethods
        def dig?(json : JSON::Any, *selector, as : T.class = String) forall T
          json.dig?(*selector).try(&.raw.as?(T))
        end

        def dig_value?(json, *selector, &)
          if (value = json.dig?(*selector))
            if (values = value.as_a?)
              values.map { |v| yield v }.first
            else
              yield value
            end
          end
        end

        def dig_values?(json, *selector, &)
          if (value = json.dig?(*selector))
            if (values = value.as_a?)
              values.map { |v| yield v }
            else
              [yield value]
            end.compact
          end
        end

        def dig_id?(json, *selector)
          dig_value?(json, *selector) do |value|
            dig_identifier(value).try(&.as_s?)
          end
        end

        def dig_ids?(json, *selector)
          dig_values?(json, *selector) do |value|
            dig_identifier(value).try(&.as_s?)
          end
        end

        private def dig_identifier(json)
          if (hash = json.as_h?)
            if hash.dig?("@type") == "https://www.w3.org/ns/activitystreams#Link"
              hash.dig?("https://www.w3.org/ns/activitystreams#href")
            else
              hash.dig?("@id")
            end
          else
            json
          end
        end
      end
    end
  end
end
