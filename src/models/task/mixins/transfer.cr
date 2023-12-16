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
    @[Insignificant]
    property failures : Array(Failure) { [] of Failure }

    def transfer(activity, from transferer, to recipients)
      actors = {} of String => ActivityPub::Actor

      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(transferer, recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.info { message }
          next
        end

        actors[recipient] = actor

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

      unless failures.empty? || actors.empty?
        account = Account.find(iri: transferer.iri)
        timezone = Time::Location.load(account.timezone)

        conditions = "running = 0 AND complete = 1 AND failures != '[]' AND created_at > datetime('now', '-10 days')"

        days = self.class.where(conditions)
          .group_by do |task|
            task.created_at.in(timezone).at_beginning_of_day
          end

        # for each recent failing recipient, count up the number of
        # recent days past with failures for that recipient. if there
        # are more than two, mark the recipient as down.

        failures.map(&.recipient).each do |recipient|
          count = days
            .transform_values do |tasks|
              tasks.any?(&.failures.any?(&.recipient.==(recipient)))
            end
            .reduce(0) do |count, (_, failure)|
              failure ? count + 1 : count
            end
          if count > 2
            actors[recipient]?.try(&.down!)
          end
        end
      end
    end
  end
end
