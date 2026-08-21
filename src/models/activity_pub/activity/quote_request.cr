require "../activity"
require "../object"
require "./accept"
require "./reject"

class ActivityPub::Activity
  class QuoteRequest < ActivityPub::Activity
    # see: Activity.recursive
    def self.recursive
      true
    end

    # NOTE: per FEP-044F, "The `QuoteRequest` activity uses the
    # `object` property to refer to the quoted object, and the
    # `instrument` property to refer to the quote post."

    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    belongs_to instrument, class_name: ActivityPub::Object, foreign_key: instrument_iri, primary_key: iri

    # Returns the accepted authorization, if one exists.
    #
    def accepted_authorization_iri : String?
      return unless (author = object?(include_deleted: true).try(&.attributed_to(include_deleted: true)))
      Accept.where(object: self, actor: author).first?.try(&.result_iri)
    end

    enum Status
      Invalid
      Awaiting
      Declined
      AuthorizationMissing    # accepted, but named no authorization
      AuthorizationUnresolved # named an authorization, but not yet resolved
      Authorized

      def label : String
        case self
        in .invalid?                  then "invalid"
        in .awaiting?                 then "awaiting approval"
        in .declined?                 then "declined"
        in .authorization_missing?    then "approved, cannot be verified"
        in .authorization_unresolved? then "approved, not verified"
        in .authorized?               then "approved"
        end
      end
    end

    def status : Status
      # include deleted -- either post may be deleted after the
      # request is answered, and that does not un-answer it.
      return Status::Invalid unless (author_iri = object?(include_deleted: true).try(&.attributed_to_iri))
      return Status::Invalid unless (quote_post = instrument?(include_deleted: true))
      return Status::Declined if Reject.where(object_iri: iri, actor_iri: author_iri).first?
      if (accept = Accept.where(object_iri: iri, actor_iri: author_iri).first?)
        return Status::AuthorizationMissing unless accept.result_iri
        return Status::AuthorizationUnresolved unless quote_post.quote_authorization_iri
        return Status::Authorized
      end
      Status::Awaiting
    end
  end
end

class ActivityPub::Object
  def quote_request?
    ActivityPub::Activity::QuoteRequest.find?(instrument: self)
  end
end
