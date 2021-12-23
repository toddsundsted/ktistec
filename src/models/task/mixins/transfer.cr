require "../../../framework/constants"
require "../../../framework/signature"

class Task
  module Transfer
    def transfer(activity, from transferer, to recipients)
      recipients.each do |recipient|
        unless (actor = ActivityPub::Actor.dereference?(transferer, recipient))
          message = "recipient does not exist: #{recipient}"
          failures << Failure.new(message)
          Log.info { message }
          next
        end
        if transferer == actor
          # no-op
        elsif (inbox = actor.inbox)
          body = activity.to_json_ld
          headers = Ktistec::Signature.sign(transferer, inbox, body, Ktistec::Constants::CONTENT_TYPE_HEADER)
          response = HTTP::Client.post(inbox, headers, body)
          unless response.success?
            message = "failed to deliver to #{inbox}: [#{response.status_code}] #{response.body}"
            failures << Failure.new(message)
            Log.info { message }
          end
        else
          message = "recipient doesn't have an inbox: #{recipient}"
          failures << Failure.new(message)
          Log.info { message }
        end
      end
    end
  end
end
