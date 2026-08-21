require "../models/activity_pub/activity/quote_request"
require "../models/activity_pub/actor"
require "../models/activity_pub/object/quote_authorization"
require "../models/task/deliver_delayed_object"

# Releases a quote post once its authorization is in hand.
#
module QuotePostReleaser
  Log = ::Log.for(self)

  # Fetches the authorization and, if it checks out, applies it to the
  # quote post and releases the post for delivery.
  #
  # Returns `true` if the post was released.
  #
  def self.release(
    key_pair,
    quote_request : ActivityPub::Activity::QuoteRequest,
    authorization_iri : String,
    deadline : Time::Instant? = nil,
  ) : Bool
    return false unless (quote_post = quote_request.instrument?)

    unless (quote_authorization = ActivityPub::Object::QuoteAuthorization.dereference?(key_pair, authorization_iri, deadline: deadline))
      Log.info { "quote post not released: authorization could not be dereferenced: #{quote_post.iri} #{authorization_iri}" }
      return false
    end
    unless (quote = quote_post.quote?) && quote_authorization.valid_for?(quote_post, quote)
      Log.info { "quote post not released: authorization is not valid: #{quote_post.iri} #{authorization_iri}" }
      return false
    end

    quote_authorization.save
    quote_post.assign(quote_authorization_iri: authorization_iri).save
    Task::DeliverDelayedObject.find?(object: quote_post).try(&.schedule)

    true
  end
end
