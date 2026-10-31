require "json"

require "../models/activity_pub/object"
require "../models/relationship/content/timeline"
require "../models/relationship/content/timeline/announce"
require "../models/relationship/content/timeline/create"

module Serializers
  # A post view-object.
  #
  struct Post
    # An attachment.
    #
    @[JSON::Serializable::Options(emit_nulls: true)]
    record Attachment, url : String, media_type : String, caption : String? do
      include JSON::Serializable
    end

    # A hashtag or mention.
    #
    @[JSON::Serializable::Options(emit_nulls: true)]
    record Tag, name : String, href : String? do
      include JSON::Serializable
    end

    getter iri : String

    getter type : String

    getter name : String?

    getter summary : String?

    getter content : String?

    getter audience : Array(String)

    getter attachments : Array(Attachment)

    getter published : Time?

    getter in_reply_to : String?

    getter thread : String?

    getter quote : String?

    getter language : String?

    getter sensitive : Bool

    getter hashtags : Array(Tag)

    getter mentions : Array(Tag)

    getter author : String?

    getter deleted : Bool

    getter blocked : Bool

    # How the post reached the feed's owner's timeline: `"create"`,
    # `"announce"`, or `nil` if it is not in their timeline.
    #
    getter timeline : String?

    def initialize(
      @iri : String,
      @type : String,
      @name : String?,
      @summary : String?,
      @content : String?,
      @audience : Array(String),
      @attachments : Array(Attachment),
      @published : Time?,
      @in_reply_to : String?,
      @thread : String?,
      @quote : String?,
      @language : String?,
      @sensitive : Bool,
      @hashtags : Array(Tag),
      @mentions : Array(Tag),
      @author : String?,
      @deleted : Bool,
      @blocked : Bool,
      @timeline : String?,
    )
    end

    # Returns a `Post` view-object.
    #
    # Facts about the post are as seen by `owner_iri`.
    #
    def self.from(object : ActivityPub::Object, owner_iri : String?) : Post
      timeline = Relationship::Content::Timeline.find?(from_iri: owner_iri, to_iri: object.iri)
      content = object.content
      content = Markd.to_html(content) if content && object.media_type == "text/markdown"
      attachments = object.attachments.try(&.map { |attachment| Attachment.new(attachment.url, attachment.media_type, attachment.caption) })
      new(
        iri: object.iri,
        type: object.type.split("::").last,
        name: object.name,
        summary: object.summary,
        content: content,
        audience: object.audience || [] of String,
        attachments: attachments || [] of Attachment,
        published: object.published,
        in_reply_to: object.in_reply_to_iri,
        thread: object.thread,
        quote: object.quote_iri,
        language: object.language,
        sensitive: object.sensitive,
        hashtags: object.hashtags.map { |hashtag| Tag.new(hashtag.name, hashtag.href) },
        mentions: object.mentions.map { |mention| Tag.new(mention.name, mention.href) },
        author: object.attributed_to_iri,
        deleted: object.deleted?,
        blocked: object.blocked?,
        timeline: timeline.try(&.type.split("::").last.downcase),
      )
    end
  end
end
