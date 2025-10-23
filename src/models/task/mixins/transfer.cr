require "../../../framework/constants"
require "../../../framework/signature"

class Task
  module Transfer
    Log = ::Log.for(self)

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

    # Determines if a recipient should be marked as "down" based on
    # recent delivery history.
    #
    # A recipient is considered "down" if there are 3+ delivery
    # failures spanning at least 80 hours, with no successful
    # deliveries to that recipient since the earliest failure.
    #
    # A delivery is deemed successful when the recipient is not in the
    # failures list.
    #
    def self.is_recipient_down?(recipient_iri : String, tasks : Array(Task)) : Bool
      failures = tasks.flat_map(&.failures).select(&.recipient.==(recipient_iri))
      return false if failures.size < 3

      earliest = failures.min_by(&.timestamp).timestamp
      latest = failures.max_by(&.timestamp).timestamp
      return false if latest - earliest < 80.hours

      !tasks.any? do |task|
        next false if task.created_at <= earliest
        !task.failures.any?(&.recipient.==(recipient_iri))
      end
    end

    def transfer(activity, from transferer, to recipients)
      actors = {} of String => ActivityPub::Actor

      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(transferer, recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.debug { message }
          next
        end

        actors[recipient] = actor

        next if actor.down?

        if transferer == actor
          # no-op
        elsif (inbox = actor.inbox)
          body = activity.to_json_ld
          headers = Ktistec::Signature.sign(transferer, inbox, body, Ktistec::Constants::CONTENT_TYPE_HEADER)
          headers["User-Agent"] = "ktistec/#{Ktistec::VERSION} (+https://github.com/toddsundsted/ktistec)"
          begin
            uri = URI.parse(inbox)
            client = HTTP::Client.new(uri)
            client.dns_timeout = 5.seconds
            client.connect_timeout = 10.seconds
            client.write_timeout = 10.seconds
            client.read_timeout = 10.seconds
            response = client.post(uri.request_target, headers, body)
            unless response.success?
              message = "failed to deliver to #{inbox}: [#{response.status_code}] #{response.body}"
              failures << Failure.new(recipient, message)
              Log.debug { message }
            end
          rescue ex: OpenSSL::Error | IO::Error
            message = "#{ex.class}: #{ex.message}: #{inbox}"
            failures << Failure.new(recipient, message)
            Log.debug { message }
          ensure
            client.try(&.close)
          end
        else
          message = "recipient doesn't have an inbox: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.debug { message }
        end
      end

      unless failures.empty? || actors.empty?
        conditions = "running = 0 AND complete = 1 AND created_at > datetime('now', '-10 days')"
        tasks = self.class.where(conditions)
        failures.map(&.recipient).each do |recipient|
          if Task::Transfer.is_recipient_down?(recipient, tasks)
            actors[recipient]?.try(&.down!)
          end
        end
      end
    end
  end
end
