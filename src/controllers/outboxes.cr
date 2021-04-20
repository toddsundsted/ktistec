require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/activity/**"
require "../models/task/deliver"

class RelationshipsController
  include Ktistec::Controller
  extend Ktistec::ViewHelper

  skip_auth ["/actors/:username/outbox"], GET

  post "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.account? == account
      forbidden
    end

    activity = env.params.body

    case activity["type"]?
    when "Announce"
      unless (iri = activity["object"]?) && (object = ActivityPub::Object.find?(iri))
        bad_request
      end
      now = Time.utc
      visible = !!activity["public"]?
      to = [] of String
      if visible
        to << "https://www.w3.org/ns/activitystreams#Public"
      end
      if (attributed_to = object.attributed_to?)
        to << attributed_to.iri
      end
      cc = [] of String
      if (followers = account.actor.followers)
        cc << followers
      end
      activity = ActivityPub::Activity::Announce.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        published: now,
        visible: visible,
        to: to,
        cc: cc
      )
    when "Like"
      unless (iri = activity["object"]?) && (object = ActivityPub::Object.find?(iri))
        bad_request
      end
      now = Time.utc
      visible = !!activity["public"]?
      to = [] of String
      if visible
        to << "https://www.w3.org/ns/activitystreams#Public"
      end
      if (attributed_to = object.attributed_to?)
        to << attributed_to.iri
      end
      cc = [] of String
      if (followers = account.actor.followers)
        cc << followers
      end
      activity = ActivityPub::Activity::Like.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        published: now,
        visible: visible,
        to: to,
        cc: cc
      )
    when "Publish"
      unless (content = activity["content"]?)
        bad_request
      end
      if (in_reply_to_iri = activity["in-reply-to"]?) && !(in_reply_to = ActivityPub::Object.find?(in_reply_to_iri))
        bad_request
      end
      if (object_iri = activity["object"]?) && !(object = ActivityPub::Object.find?(object_iri))
        bad_request
      end
      if object && object.attributed_to != account.actor
        forbidden
      end
      visible = !!activity["public"]?
      to = activity["to"]?.presence.try(&.split(",")) || [] of String
      if (attributed_to = in_reply_to.try(&.attributed_to?))
        to |= [attributed_to.iri]
      end
      if visible
        to << "https://www.w3.org/ns/activitystreams#Public"
      end
      cc = activity["cc"]?.presence.try(&.split(",")) || [] of String
      if (followers = account.actor.followers)
        cc << followers
      end
      canonical_path = activity["canonical_path"]?.try(&.presence)
      activity = (object.nil? || object.draft?) ? ActivityPub::Activity::Create.new : ActivityPub::Activity::Update.new
      object ||= ActivityPub::Object::Note.new(iri: "#{host}/objects/#{id}")
      object.assign(
        source: ActivityPub::Object::Source.new(content, "text/html; editor=trix"),
        attributed_to_iri: account.iri,
        in_reply_to: in_reply_to,
        canonical_path: canonical_path,
        visible: visible,
        to: to,
        cc: cc
      )
      # validate ensures properties are populated from source
      unless object.valid?
        unprocessable_entity "partials/editor"
      end
      # hack to sidestep typing of unions as their nearest common ancestor
      if activity.responds_to?(:actor=) && activity.responds_to?(:object=)
        activity.assign(
          iri: "#{host}/activities/#{id}",
          actor: account.actor,
          object: object,
          visible: object.visible,
          to: object.to,
          cc: object.cc
        )
      end
      unless activity.responds_to?(:valid_for_send?) && activity.valid_for_send?
        bad_request
      end
      # after validating make published
      object.published = activity.published = Time.utc
    when "Follow"
      unless (iri = activity["object"]?) && (object = ActivityPub::Actor.find?(iri))
        bad_request
      end
      activity = ActivityPub::Activity::Follow.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.iri]
      )
      unless activity.valid_for_send?
        bad_request
      end
      Relationship::Social::Follow.new(
        actor: account.actor,
        object: object,
        visible: false
      ).save
    when "Accept"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.object == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Accept.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.actor.iri]
      )
      follow.assign(confirmed: true).save
    when "Reject"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.object == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Reject.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.actor.iri]
      )
      follow.assign(confirmed: false).save
    when "Undo"
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity.find?(iri))
        bad_request
      end
      unless object.actor_iri == account.actor.iri
        bad_request
      end
      to = [] of String
      cc = [] of String
      case object
      when ActivityPub::Activity::Announce, ActivityPub::Activity::Like
        if (attributed_to = object.object.attributed_to?)
          to << attributed_to.iri
        end
        if (followers = account.actor.followers)
          cc << followers
        end
      when ActivityPub::Activity::Follow
        to << object.object.iri
        unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
          bad_request
        end
        follow.destroy
      else
        bad_request
      end
      activity = ActivityPub::Activity::Undo.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: to,
        cc: cc
      )
    when "Delete"
      if (iri = activity["object"]?)
        if (object = ActivityPub::Object.find?(iri))
          unless object.local?
            bad_request
          end
          unless object.attributed_to == account.actor
            bad_request
          end
          account.actor = object.attributed_to
          activity = object.make_delete_activity
          object.delete
        elsif (object = ActivityPub::Actor.find?(iri))
          unless object.local?
            bad_request
          end
          unless object == account.actor
            bad_request
          end
          account.actor = object
          activity = object.make_delete_activity
          object.delete
        else
          bad_request
        end
      else
        bad_request
      end
    else
      bad_request
    end

    Relationship::Content::Outbox.new(
      owner: account.actor,
      activity: activity
    ).save

    task = Task::Deliver.new(
      sender: account.actor,
      activity: activity
    )
    if Kemal.config.env == "test"
      task.perform
    else
      task.schedule
    end

    if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Update)
      if activity.object.in_reply_to?
        env.created remote_thread_path(activity.object.in_reply_to)
      else
        env.created remote_object_path(activity.object)
      end
    elsif activity.is_a?(ActivityPub::Activity::Delete) && back_path =~ /\/remote\/objects|\/objects/
      redirect actor_path
    else
      redirect back_path
    end
  end

  get "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_outbox(*pagination_params(env), public: env.account? != account)

    ok "relationships/outbox"
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end
end
