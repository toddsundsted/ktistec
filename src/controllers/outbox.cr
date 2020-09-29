require "../framework"

class RelationshipsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/outbox"], GET

  post "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    unless env.current_account? == account
      forbidden
    end

    activity = env.params.body

    case activity["type"]?
    when "Create"
      unless (content = activity["content"]?)
        bad_request
      end
      if (in_reply_to_iri = activity["in-reply-to"]?) && !ActivityPub::Object.find?(in_reply_to_iri)
        bad_request
      end
      visible = !!activity["public"]?
      to = activity["to"]?.presence.try(&.split(",")) || [] of String
      if visible
        to << "https://www.w3.org/ns/activitystreams#Public"
      end
      cc = activity["cc"]?.presence.try(&.split(",")) || [] of String
      if (followers = account.actor.followers)
        cc << followers
      end
      enhancements = Ktistec::Util.enhance(content)
      activity = ActivityPub::Activity::Create.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: ActivityPub::Object::Note.new(
          iri: "#{host}/objects/#{id}",
          media_type: "text/html",
          content: enhancements.content,
          attachments: enhancements.attachments,
          attributed_to_iri: account.iri,
          in_reply_to_iri: in_reply_to_iri,
          published: Time.utc,
          visible: visible,
          to: to,
          cc: cc
        ),
        visible: visible,
        to: to,
        cc: cc
      )
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
        object: object
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
      unless (iri = activity["object"]?) && (object = ActivityPub::Activity::Follow.find?(iri))
        bad_request
      end
      unless object.actor == account.actor
        bad_request
      end
      unless (follow = Relationship::Social::Follow.find?(from_iri: object.actor.iri, to_iri: object.object.iri))
        bad_request
      end
      activity = ActivityPub::Activity::Undo.new(
        iri: "#{host}/activities/#{id}",
        actor: account.actor,
        object: object,
        to: [object.object.iri]
      )
      follow.destroy
    when "Delete"
      if (iri = activity["object"]?)
        if (object = ActivityPub::Object.find?(iri))
          unless object.local
            bad_request
          end
          unless object.attributed_to == account.actor
            bad_request
          end
          account.actor = object.attributed_to
          activity = ActivityPub::Activity::Delete.new(
            iri: "#{host}/activities/#{id}",
            actor: account.actor,
            object: object,
            to: object.to,
            cc: object.cc
          )
          object.delete
        elsif (object = ActivityPub::Actor.find?(iri))
          unless object.local
            bad_request
          end
          unless object == account.actor
            bad_request
          end
          account.actor = object
          activity = ActivityPub::Activity::Delete.new(
            iri: "#{host}/activities/#{id}",
            actor: account.actor,
            object: object,
            to: ["https://www.w3.org/ns/activitystreams#Public"],
            cc: (_followers = object.followers) ? [_followers] : nil
          )
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

    Task::Deliver.new(
      sender: account.actor,
      activity: activity
    ).perform

    if activity.is_a?(ActivityPub::Activity::Create)
      if activity.object.in_reply_to?
        env.redirect remote_thread_path(activity.object.in_reply_to)
      else
        env.redirect remote_object_path(activity.object)
      end
    else
      env.redirect back_path
    end
  end

  get "/actors/:username/outbox" do |env|
    unless (account = get_account(env))
      not_found
    end
    activities = account.actor.in_outbox(*pagination_params(env), public: env.current_account? != account)

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/relationships/outbox.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/relationships/outbox.json.ecr"
    end
  end

  private def self.get_account(env)
    Account.find?(username: env.params.url["username"]?)
  end

  private def self.pagination_params(env)
    {
      env.params.query["page"]?.try(&.to_i) || 1,
      env.params.query["size"]?.try(&.to_i) || 10
    }
  end
end
