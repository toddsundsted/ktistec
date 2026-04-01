require "json"

require "../../ktistec/constants"
require "../../models/activity_pub/object"
require "../../models/activity_pub/object/question"
require "../../models/activity_pub/actor"
require "../../models/poll"
require "../../models/quote_decision"
require "../../models/relationship/content/bookmark"
require "../../views/view_helper"
require "./account"

module API
  module V1::Serializers
    # Serializes object data to Mastodon Status JSON format.
    #
    # See: https://docs.joinmastodon.org/entities/Status/
    #
    class Status
      include JSON::Serializable

      property id : String
      property uri : String
      property created_at : String
      property account : Account
      property content : String
      property visibility : String
      property sensitive : Bool
      property spoiler_text : String
      property media_attachments : Array(MediaAttachment)
      property mentions : Array(Mention)
      property tags : Array(Tag)
      property emojis : Array(CustomEmoji)
      property reblogs_count : Int64
      property favourites_count : Int64
      property quotes_count : Int64
      property replies_count : Int64
      @[JSON::Field(emit_null: true)]
      property url : String?
      @[JSON::Field(emit_null: true)]
      property in_reply_to_id : String?
      @[JSON::Field(emit_null: true)]
      property in_reply_to_account_id : String?
      @[JSON::Field(emit_null: true)]
      property reblog : Status?
      @[JSON::Field(emit_null: true)]
      property poll : Poll?
      @[JSON::Field(emit_null: true)]
      property card : Nil
      @[JSON::Field(emit_null: true)]
      property language : String?
      @[JSON::Field(emit_null: true)]
      property text : String?
      @[JSON::Field(emit_null: true)]
      property edited_at : String?
      @[JSON::Field(emit_null: true)]
      property quote : Quote?
      property quote_approval : QuoteApproval
      property favourited : Bool
      property reblogged : Bool
      property muted : Bool
      property bookmarked : Bool
      property pinned : Bool
      property filtered : Array(FilterResult)

      struct MediaAttachment
        include JSON::Serializable

        property id : String
        property type : String
        property url : String
        property preview_url : String
        @[JSON::Field(emit_null: true)]
        property remote_url : String?
        @[JSON::Field(emit_null: true)]
        property meta : Meta?
        @[JSON::Field(emit_null: true)]
        property description : String?
        @[JSON::Field(emit_null: true)]
        property blurhash : String?

        struct Meta
          include JSON::Serializable

          @[JSON::Field(emit_null: true)]
          property focus : Focus?

          struct Focus
            include JSON::Serializable

            property x : Float64
            property y : Float64

            def initialize(@x : Float64, @y : Float64)
            end
          end

          def initialize(@focus : Focus?)
          end
        end

        def initialize(
          @id : String,
          @type : String,
          @url : String,
          @preview_url : String,
          @remote_url : String?,
          @meta : Meta?,
          @description : String?,
          @blurhash : String?,
        )
        end
      end

      struct Mention
        include JSON::Serializable

        property id : String
        property username : String
        property url : String
        property acct : String

        def initialize(
          @id : String,
          @username : String,
          @url : String,
          @acct : String,
        )
        end
      end

      struct Tag
        include JSON::Serializable

        property name : String
        property url : String

        def initialize(@name : String, @url : String)
        end
      end

      struct CustomEmoji
        include JSON::Serializable

        property shortcode : String
        property url : String
        property static_url : String
        property visible_in_picker : Bool

        def initialize(
          @shortcode : String,
          @url : String,
          @static_url : String,
          @visible_in_picker : Bool,
        )
        end
      end

      struct Poll
        include JSON::Serializable

        property id : String
        @[JSON::Field(emit_null: true)]
        property expires_at : String?
        property expired : Bool
        property multiple : Bool
        property votes_count : Int32
        @[JSON::Field(emit_null: true)]
        property voters_count : Int32?
        property options : Array(PollOption)
        property emojis : Array(CustomEmoji)
        property voted : Bool
        property own_votes : Array(Int32)

        struct PollOption
          include JSON::Serializable

          property title : String
          @[JSON::Field(emit_null: true)]
          property votes_count : Int32?

          def initialize(@title : String, @votes_count : Int32?)
          end
        end

        def initialize(
          @id : String,
          @expires_at : String?,
          @expired : Bool,
          @multiple : Bool,
          @votes_count : Int32,
          @voters_count : Int32?,
          @options : Array(PollOption),
          @emojis : Array(CustomEmoji),
          @voted : Bool,
          @own_votes : Array(Int32),
        )
        end
      end

      struct Quote
        include JSON::Serializable

        property state : String
        @[JSON::Field(emit_null: true)]
        property quoted_status : Status?

        def initialize(@state : String, @quoted_status : Status?)
        end
      end

      struct QuoteApproval
        include JSON::Serializable

        property automatic : Array(String)
        property manual : Array(String)
        property current_user : String

        def initialize(
          @automatic : Array(String),
          @manual : Array(String),
          @current_user : String,
        )
        end
      end

      struct FilterResult
        include JSON::Serializable
      end

      def initialize(
        @id : String,
        @uri : String,
        @created_at : String,
        @account : Account,
        @content : String,
        @visibility : String,
        @sensitive : Bool,
        @spoiler_text : String,
        @media_attachments : Array(MediaAttachment),
        @mentions : Array(Mention),
        @tags : Array(Tag),
        @emojis : Array(CustomEmoji),
        @reblogs_count : Int64,
        @favourites_count : Int64,
        @quotes_count : Int64,
        @replies_count : Int64,
        @url : String?,
        @in_reply_to_id : String?,
        @in_reply_to_account_id : String?,
        @reblog : Status?,
        @poll : Poll?,
        @card : Nil,
        @language : String?,
        @text : String?,
        @edited_at : String?,
        @quote : Quote?,
        @quote_approval : QuoteApproval,
        @favourited : Bool,
        @reblogged : Bool,
        @muted : Bool,
        @bookmarked : Bool,
        @pinned : Bool,
        @filtered : Array(FilterResult),
      )
      end

      # Builds a Status from a Ktistec Object.
      #
      # Set `include_quote` to false to prevent recursive quote serialization.
      #
      def self.from_object(object : ActivityPub::Object, actor : ActivityPub::Actor? = nil, include_quote : Bool = true) : Status
        account = Account.from_actor(object.attributed_to)

        visibility = Ktistec::ViewHelper.visibility(object.attributed_to, object)
        media_attachments = build_media_attachments(object)
        poll = object.is_a?(ActivityPub::Object::Question) ? build_poll(object, actor) : nil
        quote = include_quote ? build_quote(object, actor) : nil

        if (in_reply_to = object.in_reply_to?)
          in_reply_to_id = in_reply_to.id.to_s
          in_reply_to_account_id = in_reply_to.attributed_to.id.to_s
        end

        if actor
          favourited = !!actor.find_like_for(object)
          reblogged = !!actor.find_announce_for(object)
          bookmarked = !!::Relationship::Content::Bookmark.find?(actor: actor, object: object)
        else
          favourited = false
          reblogged = false
          bookmarked = false
        end

        Status.new(
          id: object.id.to_s,
          uri: object.iri,
          created_at: object.published.not_nil!.to_rfc3339,
          account: account,
          content: object.content || "",
          visibility: visibility,
          sensitive: object.sensitive,
          spoiler_text: object.summary || "",
          media_attachments: media_attachments,
          mentions: [] of Mention,
          tags: [] of Tag,
          emojis: [] of CustomEmoji,
          reblogs_count: object.announces_count,
          favourites_count: object.likes_count,
          quotes_count: 0,
          replies_count: object.replies_count,
          url: object.urls.try(&.first?),
          in_reply_to_id: in_reply_to_id,
          in_reply_to_account_id: in_reply_to_account_id,
          reblog: nil,
          poll: poll,
          card: nil,
          language: object.language,
          text: object.source.try(&.content),
          edited_at: object.updated.try(&.to_rfc3339),
          quote: quote,
          quote_approval: QuoteApproval.new(
            automatic: ["public"],
            manual: [] of String,
            current_user: "unknown",
          ),
          favourited: favourited,
          reblogged: reblogged,
          muted: false,
          bookmarked: bookmarked,
          pinned: false,
          filtered: [] of FilterResult,
        )
      end

      private def self.build_media_attachments(object : ActivityPub::Object) : Array(MediaAttachment)
        attachments = object.attachments || [] of ActivityPub::Object::Attachment
        attachments.map_with_index do |attachment, index|
          media_type =
            if attachment.image?
              "image"
            elsif attachment.video?
              "video"
            elsif attachment.audio?
              "audio"
            else
              "unknown"
            end
          if (fp = attachment.focal_point)
            meta = MediaAttachment::Meta.new(focus: MediaAttachment::Meta::Focus.new(x: fp[0], y: fp[1]))
          end
          MediaAttachment.new(
            id: "#{object.id}_#{index}",
            type: media_type,
            url: attachment.url,
            preview_url: attachment.url,
            remote_url: nil,
            meta: meta,
            description: attachment.caption,
            blurhash: nil,
          )
        end
      end

      def self.build_poll(question : ActivityPub::Object::Question, actor : ActivityPub::Actor? = nil) : Poll?
        if (poll = question.poll?)
          options = poll.options.map do |option|
            Poll::PollOption.new(
              title: option.name,
              votes_count: option.votes_count,
            )
          end
          votes_count = poll.options.sum(&.votes_count)
          if actor
            voted = question.voted_by?(actor)
            own_votes = question.options_by(actor).compact_map do |name|
              poll.options.index { |o| o.name == name }
            end
          else
            voted = false
            own_votes = [] of Int32
          end
          Poll.new(
            id: poll.id.to_s,
            expires_at: poll.closed_at.try(&.to_rfc3339),
            expired: poll.expired?,
            multiple: poll.multiple_choice,
            votes_count: votes_count,
            voters_count: poll.multiple_choice ? poll.voters_count : nil,
            options: options,
            emojis: [] of CustomEmoji,
            voted: voted,
            own_votes: own_votes,
          )
        end
      end

      private def self.build_quote(object : ActivityPub::Object, actor : ActivityPub::Actor? = nil) : Quote?
        if (quoted_object = object.quote?)
          if object.attributed_to == quoted_object.attributed_to
            quoted_status = from_object(quoted_object, actor: actor, include_quote: false)
            Quote.new(state: "accepted", quoted_status: quoted_status)
          else
            if (authorization = object.quote_authorization?) && (decision = authorization.quote_decision?)
              case decision.decision
              when "accept"
                quoted_status = from_object(quoted_object, actor: actor, include_quote: false)
                Quote.new(state: "accepted", quoted_status: quoted_status)
              when "reject"
                Quote.new(state: "rejected", quoted_status: nil)
              else
                Quote.new(state: "pending", quoted_status: nil)
              end
            else
              Quote.new(state: "pending", quoted_status: nil)
            end
          end
        elsif object.quote_iri
          Quote.new(state: "deleted", quoted_status: nil)
        end
      end
    end
  end
end
