require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/account"
require "../rules/content_rules"
require "../models/task/handle_follow_request"
require "../models/task/receive"
require "../models/task/deliver"
require "../models/task/deliver_delayed_object"
require "../models/relationship/social/follow"
require "../models/activity_pub/object/quote_authorization"
require "../models/quote_decision"

class InboxActivityProcessor
  # Processes an inbound activity that has already been received,
  # validated, and saved.
  #
  # Processes the activity through content rules, handles
  # activity-specific side-effects, and schedules receive task.
  #
  # Preconditions:
  # - activity must be saved
  # - activity must be from a remote actor
  # - account.actor must be the recipient
  #
  def self.process(
    account : Account,
    activity : ActivityPub::Activity,
    deliver_to : Array(String)? = nil,
    content_rules : ContentRules = ContentRules.new,
    handle_follow_request_task_class : Task::HandleFollowRequest.class = Task::HandleFollowRequest,
    receive_task_class : Task::Receive.class = Task::Receive,
    deliver_task_class : Task::Deliver.class = Task::Deliver,
  )
    content_rules.run do
      recipients = [activity.to, activity.cc, deliver_to].flatten.compact.uniq!
      recipients.each { |recipient| assert ContentRules::IsRecipient.new(recipient) }
      assert ContentRules::Incoming.new(account.actor, activity)
    end

    case activity
    when ActivityPub::Activity::Follow
      if activity.object == account.actor
        unless Relationship::Social::Follow.find?(actor: activity.actor, object: activity.object)
          Relationship::Social::Follow.new(
            actor: activity.actor,
            object: activity.object,
            visible: false
          ).save(skip_associated: true)
        end
        handle_follow_request_task_class.new(
          recipient: account.actor,
          activity: activity
        ).schedule
      end
    when ActivityPub::Activity::QuoteRequest
      process_quote_request(account, activity, deliver_task_class)
    when ActivityPub::Activity::Accept
      case (object = activity.object)
      when ActivityPub::Activity::Follow
        if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: object.object))
          follow.assign(confirmed: true).save
        end
      when ActivityPub::Activity::QuoteRequest
        process_accept_quote_request(account, object, activity)
      end
    when ActivityPub::Activity::Reject
      case (object = activity.object)
      when ActivityPub::Activity::Follow
        if (follow = Relationship::Social::Follow.find?(actor: activity.object.actor, object: object.object))
          follow.assign(confirmed: true).save
        end
      when ActivityPub::Activity::QuoteRequest
        # no action needed
      end
    when ActivityPub::Activity::Undo
      case (object = activity.object)
      when ActivityPub::Activity::Follow
        if (follow = Relationship::Social::Follow.find?(actor: object.actor, object: object.object))
          follow.destroy
        end
      end
      activity.object.undo!
    when ActivityPub::Activity::Delete
      case (object = activity.object?)
      when ActivityPub::Object
        object.delete!
      when ActivityPub::Actor
        object.delete!
      end
    end

    receive_task_class.new(
      receiver: account.actor,
      activity: activity,
      deliver_to: deliver_to
    ).schedule
  end

  private def self.process_accept_quote_request(account, quote_request, accept)
    if (quote_post = quote_request.instrument?)
      quote_post.assign(quote_authorization_iri: accept.result_iri).save
      if (quote_authorization_iri = accept.result_iri)
        if (quote_authorization = ActivityPub::Object::QuoteAuthorization.dereference?(account.actor, quote_authorization_iri))
          if (quote_decision = quote_authorization.quote_decision?) &&
             quote_decision.interacting_object? == quote_post &&
             quote_decision.interaction_target? == quote_post.quote &&
             quote_authorization.attributed_to? == accept.actor
            quote_authorization.save
          end
        end
      end
      Task::DeliverDelayedObject.find?(object: quote_post).try(&.schedule)
    end
  end

  private def self.process_quote_request(account, quote_request, deliver_task_class)
    quoted_post = quote_request.object
    quoting_post_iri = quote_request.instrument_iri

    now = Time.utc

    existing = QuoteDecision
      .where(interaction_target_iri: quoted_post.iri, interacting_object_iri: quoting_post_iri)
      .first?

    if existing
      authorization = existing.quote_authorization
    else
      decision = QuoteDecision.new(
        interaction_target_iri: quoted_post.iri,
        interacting_object_iri: quoting_post_iri,
        decision: "accept"
      )
      authorization = ActivityPub::Object::QuoteAuthorization.new(
        iri: "#{Ktistec.host}/objects/#{Ktistec::Util.id}",
        quote_decision: decision,
        attributed_to: account.actor,
        visible: quoted_post.visible,
        published: now,
      )
      authorization.save
    end

    accept = ActivityPub::Activity::Accept.new(
      iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
      actor: account.actor,
      object: quote_request,
      result: authorization,
      to: [quote_request.actor.iri],
      published: now,
    ).save

    OutboxActivityProcessor.process(account, accept, deliver_task_class: deliver_task_class)
  end
end
