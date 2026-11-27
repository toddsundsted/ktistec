require "../../../ktistec/constants"
require "../../../utils/network"

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

    class State
      include JSON::Serializable

      property recipients : Array(String)?

      property pending : Array(String)?

      property attempts : Int32 = 0

      def initialize(@recipients = nil)
      end
    end

    MAX_RETRIES = 6

    BASE_RETRY_DELAY = 5.minutes

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    @[Assignable]
    @recipients : Array(String)?

    def recipients
      state.recipients || [] of String
    end

    def recipients=(@recipients : Array(String)?)
      state.recipients = recipients
    end

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
    # failures spanning at least DOWN_DETECTION_SPAN, with no
    # successful deliveries to that recipient since the earliest
    # failure.
    #
    # A delivery is deemed successful when the task was addressed to
    # the recipient and the recipient is not in the failures list.
    #
    def self.recipient_down?(recipient_iri : String, tasks : Array(Task)) : Bool
      failures = tasks.flat_map(&.failures).select(&.recipient.==(recipient_iri))
      return false if failures.size < 3

      earliest = failures.min_by(&.timestamp).timestamp
      latest = failures.max_by(&.timestamp).timestamp
      return false if latest - earliest < Task::DOWN_DETECTION_SPAN

      !tasks.any? do |task|
        next false if task.created_at <= earliest
        next false unless task.recipients.includes?(recipient_iri)
        !task.failures.any?(&.recipient.==(recipient_iri))
      end
    end

    # Returns `true` if a delivery that failed with the given response
    # status might succeed later.
    #
    def self.transient_status?(status_code : Int32) : Bool
      status_code.in?(401, 408, 429) || status_code >= 500
    end

    # Transfers the activity to the recipients, and schedules a retry
    # of the recipients whose delivery failed transiently.
    #
    def transfer(activity, from transferer)
      can_retry = state.attempts < MAX_RETRIES
      transient = transfer(activity, from: transferer, to: state.pending || recipients, can_retry: can_retry)
      if can_retry && !transient.empty?
        state.pending = transient
        state.attempts += 1
        self.next_attempt_at = randomized_next_attempt_at(BASE_RETRY_DELAY * 2 ** (state.attempts - 1))
      end
    end

    # Transfers the activity to the recipients.
    #
    # Clears earlier failures for recipients the activity is delivered
    # to. Returns the recipients whose delivery failed transiently.
    #
    def transfer(activity, from transferer, to recipients, can_retry = false)
      recipient_to_actor = {} of String => ActivityPub::Actor
      inbox_to_recipients = {} of String => Array(String)
      transient_recipients = [] of String

      # dereference all recipients and group by target inbox
      recipients.each do |recipient|
        begin
          actor = ActivityPub::Actor.dereference(transferer, recipient, deadline: nil)
        rescue ex : Ktistec::Network::TransientError
          message = "failed to dereference recipient: #{recipient}: #{ex.message}"
          failures << Failure.new(recipient, message)
          transient_recipients << recipient
          Log.debug { message }
          next
        rescue Ktistec::Network::PermanentError | Ktistec::Model::NotFound | Ktistec::JSON_LD::Error | JSON::ParseException | NotImplementedError
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

      # deliver once per unique inbox, with fallback from shared to personal inboxes
      work_queue = inbox_to_recipients.to_a
      while (entry = work_queue.shift?)
        inbox, inbox_recipients = entry
        body = activity.to_json_ld
        success = false
        transient = false
        message = ""
        begin
          response = Ktistec::Network.post(transferer, inbox, body, Ktistec::Constants::CONTENT_TYPE_HEADER)
          if response.success?
            success = true
          else
            transient = Transfer.transient_status?(response.status_code)
            message = "failed to deliver to #{inbox}: [#{response.status_code}] #{response.body}"
            Log.debug { sanitize_log_message(message) }
          end
        rescue ex : Ktistec::Network::TransientError
          transient = true
          message = "#{ex.message}"
          Log.debug { message }
        rescue ex : Ktistec::Network::Error
          message = "#{ex.message}"
          Log.debug { message }
        end
        if success
          failures.reject!(&.recipient?.in?(inbox_recipients))
        else
          # retry each recipient's personal inbox, if that is not the
          # inbox that failed. otherwise, record the failure.
          fallback_inboxes = {} of String => Array(String)
          inbox_recipients.each do |recipient|
            if (actor = recipient_to_actor[recipient]?) && (actor_inbox = actor.inbox) && actor_inbox != inbox
              fallback_inboxes[actor_inbox] ||= [] of String
              fallback_inboxes[actor_inbox] << recipient
            else
              failures << Failure.new(recipient, message)
              transient_recipients << recipient if transient
            end
          end
          fallback_inboxes.each do |actor_inbox, recipients_for_inbox|
            work_queue << {actor_inbox, recipients_for_inbox}
          end
        end
      end

      # a recipient that will be retried is checked on its last attempt
      retrying = can_retry ? transient_recipients : [] of String

      unless failures.empty? || recipient_to_actor.empty?
        conditions = "running = 0 AND complete = 1 AND created_at > datetime('now', '-10 days')"
        tasks = self.class.where(conditions)
        failures.map(&.recipient).each do |recipient|
          next if recipient.in?(retrying)
          if Task::Transfer.recipient_down?(recipient, tasks)
            recipient_to_actor[recipient]?.try(&.down!)
          end
        end
      end

      transient_recipients
    end
  end
end
