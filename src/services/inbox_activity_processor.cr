require "../models/activity_pub/activity"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/account"
require "../models/filter_term"
require "../rules/trigger"
require "../models/task/handle_follow_request"
require "../models/task/receive"
require "../models/task/deliver"
require "../models/task/deliver_delayed_object"
require "../models/relationship/content/inbox"
require "../models/relationship/social/follow"
require "../models/relationship/content/notification/quote"
require "../models/activity_pub/object/quote_authorization"
require "../models/quote_decision"
require "../utils/recipients"

class InboxActivityProcessor
  Log = ::Log.for(self)

  # Processes an inbound activity that has already been received,
  # validated, and saved.
  #
  # Decides whether the activity is accepted into the recipient's
  # inbox, handles activity-specific side-effects, re-evaluates the
  # materialized views, and schedules receive task.
  #
  # Preconditions:
  # - activity must be saved
  # - activity must be from a remote actor
  # - account.actor must be the recipient when `recipients` is not
  #   supplied -- when it is, `account` is unused and may be `nil`
  #
  def self.process(
    account : Account?,
    activity : ActivityPub::Activity,
    deliver_to : Array(String)? = nil,
    recipients : Array(Account)? = nil,
    handle_follow_request_task_class : Task::HandleFollowRequest.class = Task::HandleFollowRequest,
    receive_task_class : Task::Receive.class = Task::Receive,
    deliver_task_class : Task::Deliver.class = Task::Deliver,
  )
    (recipients || [account].compact).each do |recipient|
      deliver(
        recipient, activity, deliver_to,
        handle_follow_request_task_class: handle_follow_request_task_class,
        deliver_task_class: deliver_task_class,
      )
    end

    maintain(activity)

    if recipients
      forwarding = Ktistec::Recipients.forwarding(activity)

      # the forwarding account signs the transfer -- they own the
      # followers collection being expanded -- otherwise any
      # implicated account supplies the fetch identity.

      if (receiver = forwarding.try(&.account) || recipients.first?)
        receive_task_class.new(
          receiver: receiver.actor,
          activity: activity,
          recipients: forwarding.try(&.recipients) || [] of String,
        ).schedule
      end
    elsif account
      partition = Ktistec::Recipients.partition(
        Ktistec::Recipients.for_receive(activity, account.actor, deliver_to),
      )

      # scheduled unconditionally.

      receive_task_class.new(
        receiver: account.actor,
        activity: activity,
        recipients: partition.remote,
      ).schedule
    end
  end

  # Produces the delivery artifacts for a local account and the side
  # effects that belong to the account the activity implicates.
  #
  def self.deliver(
    account : Account,
    activity : ActivityPub::Activity,
    deliver_to : Array(String)? = nil,
    handle_follow_request_task_class : Task::HandleFollowRequest.class = Task::HandleFollowRequest,
    deliver_task_class : Task::Deliver.class = Task::Deliver,
  )
    if Ktistec::Recipients.recipient?(activity, account.actor, deliver_to) && !filtered?(account.actor, activity)
      unless Relationship::Content::Inbox.find?(owner: account.actor, activity: activity)
        Relationship::Content::Inbox.new(owner: account.actor, activity: activity).save
      end
    end

    case activity
    when ActivityPub::Activity::Follow
      if Ktistec::Recipients.semantic_recipient?(activity, account.actor)
        unless Relationship::Social::Follow.find?(actor: activity.actor, object: activity.object)
          Relationship::Social::Follow.new(
            actor: activity.actor,
            object: activity.object,
            visible: false,
          ).save(skip_associated: true)
        end
        handle_follow_request_task_class.new(
          recipient: account.actor,
          activity: activity,
        ).schedule
      end
    when ActivityPub::Activity::QuoteRequest
      if Ktistec::Recipients.semantic_recipient?(activity, account.actor)
        process_quote_request(account, activity, deliver_task_class)
      end
    when ActivityPub::Activity::Accept
      if (object = activity.object).is_a?(ActivityPub::Activity::QuoteRequest)
        if Ktistec::Recipients.semantic_recipient?(activity, account.actor)
          process_accept_quote_request(account, object, activity)
        end
      end
    end
  end

  # Corrects the local cache to match the state of the fediverse, and
  # re-evaluates the materialized views.
  #
  def self.maintain(activity : ActivityPub::Activity)
    case activity
    when ActivityPub::Activity::Accept, ActivityPub::Activity::Reject
      if (object = activity.object).is_a?(ActivityPub::Activity::Follow)
        if (follow = Relationship::Social::Follow.find?(actor: object.actor, object: object.object))
          follow.assign(confirmed: true).save
        end
      end
    when ActivityPub::Activity::Undo
      object =
        if (object_iri = activity.object_iri)
          ActivityPub::Activity.find?(object_iri, include_undone: true)
        end
      object ||= activity.object?(include_undone: true)
      if object && !object.undone?
        if object.is_a?(ActivityPub::Activity::Follow)
          if (follow_actor = object.actor?) && (follow_object = object.object?)
            if (follow = Relationship::Social::Follow.find?(actor: follow_actor, object: follow_object))
              follow.destroy
            end
          end
        end
        object.undo!
      end
    when ActivityPub::Activity::Delete
      object =
        if (object_iri = activity.object_iri)
          ActivityPub::Object.find?(object_iri, include_deleted: true) ||
            ActivityPub::Actor.find?(object_iri, include_deleted: true)
        end
      object ||= activity.object?(include_deleted: true)
      if object && !object.deleted?
        object.delete!
      end
    end

    # re-evaluate the materialized views for the object this activity
    # concerns.
    Rules::Trigger.reconcile_for_activity(activity)
  end

  # Processes local recipients in-process.
  #
  def self.process_locally(actors_accounts : Array(Tuple(ActivityPub::Actor, Account)), activity : ActivityPub::Activity)
    actors_accounts.each do |actor, account|
      next if Relationship::Content::Inbox.find?(owner: actor, activity: activity)
      process(account, activity, deliver_to: [actor.iri])
    end
  end

  private def self.filtered?(receiver : ActivityPub::Actor, activity : ActivityPub::Activity) : Bool
    case activity
    when ActivityPub::Activity::Create, ActivityPub::Activity::Announce
      if (object = activity.object?) && activity.actor? != receiver
        FilterTerm.match?(receiver, object.content)
      else
        false
      end
    else
      false
    end
  end

  private def self.process_accept_quote_request(account, quote_request, accept)
    return unless (quoted_post = quote_request.object?)
    return unless (actor_iri = accept.actor_iri) && actor_iri == quoted_post.attributed_to_iri

    # every path that does not release the quote post logs why.
    # the post remains an unpublished draft.
    return unless (quote_post = quote_request.instrument?)

    unless (quote_authorization_iri = accept.result_iri)
      Log.info { "quote post not released: accept has no result: #{quote_post.iri}" }
      return
    end
    unless (quote_authorization = ActivityPub::Object::QuoteAuthorization.dereference?(account.actor, quote_authorization_iri))
      Log.info { "quote post not released: authorization could not be dereferenced: #{quote_post.iri} #{quote_authorization_iri}" }
      return
    end
    unless (quote = quote_post.quote?) && quote_authorization.valid_for?(quote_post, quote)
      Log.info { "quote post not released: authorization is not valid: #{quote_post.iri} #{quote_authorization_iri}" }
      return
    end

    quote_authorization.save
    quote_post.assign(quote_authorization_iri: quote_authorization_iri).save
    Task::DeliverDelayedObject.find?(object: quote_post).try(&.schedule)
  end

  private def self.process_quote_request(account, quote_request, deliver_task_class)
    now = Time.utc

    # a request is answered once, and stays answered across a
    # redelivery regardless of the current `manually_approve_quotes`
    # setting.
    if ActivityPub::Activity::Accept.where(actor_iri: account.actor.iri, object_iri: quote_request.iri).first? ||
       ActivityPub::Activity::Reject.where(actor_iri: account.actor.iri, object_iri: quote_request.iri).first?
      return
    end

    if account.manually_approve_quotes
      reject = ActivityPub::Activity::Reject.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: account.actor,
        object: quote_request,
        to: [quote_request.actor.iri],
        published: now,
      ).save

      OutboxActivityProcessor.process(account, reject, deliver_task_class: deliver_task_class)
    else
      quoted_post = quote_request.object
      quoting_post_iri = quote_request.instrument_iri

      existing = QuoteDecision
        .where(interaction_target_iri: quoted_post.iri, interacting_object_iri: quoting_post_iri)
        .first?

      if existing
        authorization = existing.quote_authorization
      else
        decision = QuoteDecision.new(
          interaction_target_iri: quoted_post.iri,
          interacting_object_iri: quoting_post_iri,
          decision: "accept",
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

      Relationship::Content::Notification::Quote.new(
        owner: account.actor,
        activity: quote_request,
      ).save
    end
  end
end
