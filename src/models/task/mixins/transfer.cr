require "../../../framework/constants"
require "../../../framework/signature"

class Task
  module Transfer
    class Failure
      include JSON::Serializable

      # for backward compatibility with older databases, the
      # `recipient` property must allow null values to be assigned
      # during deserialization.

      property! recipient : String

      property description : String

      property timestamp : Time

      def initialize(@recipient, @description, @timestamp = Time.utc)
      end
    end

    @[Persistent]
    property failures : Array(Failure) { [] of Failure }

    def transfer(activity, from transferer, to recipients)
      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(transferer, recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.info { message }
          next
        end

        next if actor.down?

        if transferer == actor
          # no-op
        elsif (inbox = actor.inbox)
          body = activity.to_json_ld
          headers = Ktistec::Signature.sign(transferer, inbox, body, Ktistec::Constants::CONTENT_TYPE_HEADER)
          begin
            response = HTTP::Client.post(inbox, headers, body)
            unless response.success?
              message = "failed to deliver to #{inbox}: [#{response.status_code}] #{response.body}"
              failures << Failure.new(recipient, message)
              Log.info { message }
            end
          rescue ex: OpenSSL::Error | Socket::Error
            message = "#{ex.class}: #{ex.message}: #{inbox}"
            failures << Failure.new(recipient, message)
            Log.info { message }
          end
        else
          message = "recipient doesn't have an inbox: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.info { message }
        end
      end
    end
  end
end
