{% if flag?(:with_mastodon_api) %}
  require "json"

  require "../../models/activity_pub/actor"

  module API
    module V1::Serializers
      # Serializes relationship data to Mastodon Relationship JSON format.
      #
      # See: https://docs.joinmastodon.org/entities/Relationship/
      #
      struct Relationship
        include JSON::Serializable

        property id : String
        property following : Bool
        property showing_reblogs : Bool
        property notifying : Bool
        property followed_by : Bool
        property blocking : Bool
        property blocked_by : Bool
        property muting : Bool
        property muting_notifications : Bool
        property requested : Bool
        property requested_by : Bool
        property domain_blocking : Bool
        property endorsed : Bool
        property note : String

        def initialize(
          @id : String,
          @following : Bool,
          @showing_reblogs : Bool,
          @notifying : Bool,
          @followed_by : Bool,
          @blocking : Bool,
          @blocked_by : Bool,
          @muting : Bool,
          @muting_notifications : Bool,
          @requested : Bool,
          @requested_by : Bool,
          @domain_blocking : Bool,
          @endorsed : Bool,
          @note : String,
        )
        end

        def self.from_actors(actor : ActivityPub::Actor, other : ActivityPub::Actor) : Relationship
          follow = actor.follows?(other)
          following = follow ? !!follow.accepted? : false
          follow_by = other.follows?(actor)
          followed_by = follow_by ? !!follow_by.accepted? : false
          requested = follow ? follow.pending? : false
          blocking = other.blocked?

          Relationship.new(
            id: other.id.to_s,
            following: following,
            showing_reblogs: true,
            notifying: false,
            followed_by: followed_by,
            blocking: blocking,
            blocked_by: false,
            muting: false,
            muting_notifications: false,
            requested: requested,
            requested_by: false,
            domain_blocking: false,
            endorsed: false,
            note: "",
          )
        end
      end
    end
  end
{% end %}
