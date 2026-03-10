{% if flag?(:with_mastodon_api) %}
  require "json"

  require "../../models/account"
  require "../../models/activity_pub/actor"
  require "../../models/relationship/social/follow"

  module API
    module V1::Serializers
      # Serializes account data to Mastodon Account JSON format.
      #
      # See: https://docs.joinmastodon.org/entities/Account/
      #
      struct Account
        include JSON::Serializable

        property id : String
        property username : String
        property acct : String
        property url : String
        property uri : String
        property display_name : String
        property note : String
        property avatar : String
        property avatar_static : String
        property header : String
        property header_static : String
        property locked : Bool
        property fields : Array(Field)
        property emojis : Array(JSON::Any)
        property bot : Bool
        property group : Bool
        property discoverable : Bool?
        property indexable : Bool
        property created_at : String
        @[JSON::Field(emit_null: true)]
        property last_status_at : String?
        property statuses_count : Int64
        property followers_count : Int64
        property following_count : Int64
        @[JSON::Field(emit_null: true)]
        property source : Source?

        struct Field
          include JSON::Serializable

          property name : String
          property value : String
          @[JSON::Field(emit_null: true)]
          property verified_at : String?

          def initialize(
            @name : String,
            @value : String,
            @verified_at : String? = nil,
          )
          end
        end

        struct Source
          include JSON::Serializable

          property attribution_domains : Array(String)
          property note : String
          property fields : Array(Field)
          property privacy : String
          property sensitive : Bool
          property language : String
          property follow_requests_count : Int64
          property indexable : Bool
          property quote_policy : String

          def initialize(
            @attribution_domains : Array(String),
            @note : String,
            @fields : Array(Field),
            @privacy : String,
            @sensitive : Bool,
            @language : String,
            @follow_requests_count : Int64,
            @indexable : Bool,
            @quote_policy : String,
          )
          end
        end

        def initialize(
          @id : String,
          @username : String,
          @acct : String,
          @url : String,
          @uri : String,
          @display_name : String,
          @note : String,
          @avatar : String,
          @avatar_static : String,
          @header : String,
          @header_static : String,
          @locked : Bool,
          @fields : Array(Field),
          @emojis : Array(JSON::Any),
          @bot : Bool,
          @group : Bool,
          @discoverable : Bool?,
          @indexable : Bool,
          @created_at : String,
          @last_status_at : String?,
          @statuses_count : Int64,
          @followers_count : Int64,
          @following_count : Int64,
          @source : Source?,
        )
        end

        # Builds an Account from a Ktistec Account and Actor.
        #
        # When `include_source` is true, includes the `source` field.
        #
        def self.from_account(account : ::Account, actor : ActivityPub::Actor, include_source : Bool = false) : Account
          fields = build_fields(actor)

          source =
            if include_source
              Source.new(
                attribution_domains: [] of String,
                note: Ktistec::Util.render_as_text(actor.summary).strip,
                fields: fields,
                privacy: "public",
                sensitive: false,
                language: account.language || "",
                follow_requests_count: Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: false),
                indexable: false,
                quote_policy: account.manually_approve_quotes ? "approval" : "public",
              )
            end

          avatar = actor.icon || ""
          header = actor.image || ""

          Account.new(
            id: actor.id.to_s,
            username: account.username,
            acct: (actor.local? ? actor.username : actor.handle) || "",
            url: actor.urls.try(&.first?) || actor.iri,
            uri: actor.iri,
            display_name: actor.name || "",
            note: actor.summary || "",
            avatar: avatar,
            avatar_static: avatar,
            header: header,
            header_static: header,
            locked: !account.auto_approve_followers,
            fields: fields,
            emojis: [] of JSON::Any,
            bot: actor.type.in?("ActivityPub::Actor::Service", "ActivityPub::Actor::Application"),
            group: actor.type == "ActivityPub::Actor::Group",
            discoverable: true,
            indexable: false,
            created_at: actor.created_at.not_nil!.to_rfc3339,
            last_status_at: last_status_at(actor),
            statuses_count: actor.all_posts(Time.unix(0)),
            followers_count: Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: true),
            following_count: Relationship::Social::Follow.count(from_iri: actor.iri, confirmed: true),
            source: source,
          )
        end

        # Builds an Account from a Ktistec Actor.
        #
        # For remote actors.
        #
        def self.from_actor(actor : ActivityPub::Actor) : Account
          fields = build_fields(actor)

          avatar = actor.icon || ""
          header = actor.image || ""

          Account.new(
            id: actor.id.to_s,
            username: actor.username || "",
            acct: (actor.local? ? actor.username : actor.handle) || "",
            url: actor.urls.try(&.first?) || actor.iri,
            uri: actor.iri,
            display_name: actor.name || "",
            note: actor.summary || "",
            avatar: avatar,
            avatar_static: avatar,
            header: header,
            header_static: header,
            locked: false,
            fields: fields,
            emojis: [] of JSON::Any,
            bot: actor.type.in?("ActivityPub::Actor::Service", "ActivityPub::Actor::Application"),
            group: actor.type == "ActivityPub::Actor::Group",
            discoverable: true,
            indexable: false,
            created_at: actor.created_at.not_nil!.to_rfc3339,
            last_status_at: last_status_at(actor),
            statuses_count: actor.all_posts(Time.unix(0)),
            followers_count: Relationship::Social::Follow.count(to_iri: actor.iri, confirmed: true),
            following_count: Relationship::Social::Follow.count(from_iri: actor.iri, confirmed: true),
            source: nil,
          )
        end

        private def self.build_fields(actor : ActivityPub::Actor) : Array(Field)
          (actor.attachments || [] of ActivityPub::Actor::Attachment).map do |attachment|
            Field.new(name: attachment.name, value: attachment.value)
          end
        end

        private def self.last_status_at(actor : ActivityPub::Actor) : String?
          unless (posts = actor.public_posts(page: 1, size: 1)).empty?
            posts.first.published.try(&.to_s("%Y-%m-%d"))
          end
        end
      end
    end
  end
{% end %}
