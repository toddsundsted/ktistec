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

    # Sanitizes a message for logging.
    #
    private def sanitize_log_message(message : String, max_length : Int32 = 200) : String
      sanitized = message.gsub(/\r?\n/, "\\n")
      if sanitized.size > max_length
        sanitized[0, max_length - 3] + "..."
      else
        sanitized
      end
    end

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
    def self.recipient_down?(recipient_iri : String, tasks : Array(Task)) : Bool
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
      recipient_to_actor = {} of String => ActivityPub::Actor
      inbox_to_recipients = {} of String => Array(String)

      # dereference all recipients and group by target inbox
      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(transferer, recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.debug { message }
          next
        end
        recipient_to_actor[recipient] = actor
        next if actor.down? || transferer == actor
        target_inbox = actor.shared_inbox || actor.inbox
        if target_inbox
          inbox_to_recipients[target_inbox] ||= [] of String
          inbox_to_recipients[target_inbox] << recipient
        else
          message = "recipient doesn't have an inbox: #{recipient}"
          failures << Failure.new(recipient, message)
          Log.debug { message }
        end
      end

      # deliver once per unique inbox
      inbox_to_recipients.each do |inbox, inbox_recipients|
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
            # track failure for recipients using this inbox
            inbox_recipients.each do |recipient|
              failures << Failure.new(recipient, message)
            end
            Log.debug { sanitize_log_message(message) }
          end
        rescue ex : OpenSSL::Error | IO::Error
          message = "#{ex.class}: #{ex.message}: #{inbox}"
          # track failure for recipients using this inbox
          inbox_recipients.each do |recipient|
            failures << Failure.new(recipient, message)
          end
          Log.debug { message }
        ensure
          client.try(&.close)
        end
      end

      unless failures.empty? || recipient_to_actor.empty?
        conditions = "running = 0 AND complete = 1 AND created_at > datetime('now', '-10 days')"
        tasks = self.class.where(conditions)
        failures.map(&.recipient).each do |recipient|
          if Task::Transfer.recipient_down?(recipient, tasks)
            recipient_to_actor[recipient]?.try(&.down!)
          end
        end
      end
    end
  end
end
