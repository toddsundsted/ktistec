require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../../framework/util"
require "../activity_pub"
require "../activity_pub/actor"

module ActivityPub
  class Object
    include Ktistec::Model(Common, Deletable, Polymorphic, Serialized, Linked)
    include ActivityPub

    @@table_name = "objects"

    @[Persistent]
    property visible : Bool { false }

    @[Persistent]
    property published : Time?

    @[Persistent]
    property attributed_to_iri : String?
    belongs_to attributed_to, class_name: ActivityPub::Actor, foreign_key: attributed_to_iri, primary_key: iri

    @[Persistent]
    property in_reply_to_iri : String?
    belongs_to in_reply_to, class_name: ActivityPub::Object, foreign_key: in_reply_to_iri, primary_key: iri

    @[Persistent]
    property replies : String?

    @[Persistent]
    property to : Array(String)?

    @[Persistent]
    property cc : Array(String)?

    @[Persistent]
    property summary : String?

    @[Persistent]
    property content : String?

    @[Persistent]
    property media_type : String?

    @[Persistent]
    property source : Source?

    alias Attachment = Ktistec::Util::Attachment

    @[Persistent]
    property attachments : Array(Attachment)?

    @[Persistent]
    property urls : Array(String)?

    def display_link
      urls.try(&.first?) || iri
    end

    def display_date
      (published || created_at).to_local.to_s("%l:%M%P · %b %-d, %Y").lstrip(' ')
    end

    struct Source
      include JSON::Serializable

      property content : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      def initialize(@content, @media_type)
      end
    end

    @[Assignable]
    property announces : Int64 = 0

    @[Assignable]
    property likes : Int64 = 0

    def with_statistics!
      query = <<-QUERY
         SELECT sum(a.type = "ActivityPub::Activity::Announce") AS announces, sum(a.type = "ActivityPub::Activity::Like") AS likes
           FROM activities AS a
      LEFT JOIN activities AS u
             ON u.object_iri = a.iri
            AND u.type = "ActivityPub::Activity::Undo"
            AND u.actor_iri = a.actor_iri
          WHERE u.iri IS NULL
            AND a.object_iri = ?
      QUERY
      Ktistec.database.query_one(query, iri) do |rs|
        rs.read(Int64?).try { |announces| self.announces = announces }
        rs.read(Int64?).try { |likes| self.likes = likes }
      end
      self
    end

    @[Assignable]
    property depth : Int32 = 0

    def thread
      query = <<-QUERY
           WITH RECURSIVE
            ancestors_of(iri, depth) AS (
                 VALUES(?, 0)
                  UNION
                 SELECT o.in_reply_to_iri AS iri, p.depth + 1 AS depth
                   FROM objects AS o, ancestors_of AS p
                  WHERE o.iri = p.iri AND o.in_reply_to_iri IS NOT NULL
               ORDER BY depth DESC
            ),
            replies_to(iri, position, depth) AS (
               SELECT * FROM (SELECT iri, "", 0 FROM ancestors_of ORDER BY depth DESC LIMIT 1)
                  UNION
                 SELECT o.iri, r.position || "." || o.id, r.depth + 1 AS depth
                   FROM objects AS o, replies_to AS r
                  WHERE o.in_reply_to_iri = r.iri
               ORDER BY depth DESC
             )
         SELECT #{Object.columns(prefix: "o")}, sum(c.announces), sum(c.likes), r.depth
           FROM objects AS o, replies_to AS r
      LEFT JOIN (   SELECT a.id, a.object_iri, a.actor_iri, (a.type = "ActivityPub::Activity::Announce") AS announces, (a.type = "ActivityPub::Activity::Like") AS likes
                      FROM activities AS a
                 LEFT JOIN activities AS u
                        ON u.object_iri = a.iri
                       AND u.type = "ActivityPub::Activity::Undo"
                       AND u.actor_iri = a.actor_iri
                     WHERE u.iri IS NULL
                ) AS c
             ON c.object_iri = o.iri
          WHERE o.iri IN (r.iri)
           AND o.deleted_at IS NULL
         GROUP BY o.id
         ORDER BY r.position
      QUERY
      Object.query_all(query, self.iri, additional_columns: {announces: Int64?, likes: Int64?, depth: Int32})
    end

    def ancestors
      query = <<-QUERY
        WITH RECURSIVE
         ancestors_of(iri, depth) AS (
              VALUES(?, 0)
               UNION
              SELECT o.in_reply_to_iri AS iri, p.depth + 1 AS depth
                FROM objects AS o, ancestors_of AS p
               WHERE o.iri = p.iri AND o.in_reply_to_iri IS NOT NULL
            ORDER BY depth DESC
         )
      SELECT #{Object.columns(prefix: "o")}, a.depth
        FROM objects AS o, ancestors_of AS a
       WHERE o.iri IN (a.iri)
         AND o.deleted_at IS NULL
      QUERY
      Object.query_all(query, self.iri, additional_columns: {depth: Int32})
    end

    def to_json_ld(recursive = false)
      object = self
      render "src/views/objects/object.json.ecr"
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        iri: json.dig?("@id").try(&.as_s),
        _type: json.dig?("@type").try(&.as_s.split("#").last),
        published: (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        attributed_to_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#attributedTo"),
        in_reply_to_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#inReplyTo"),
        replies: dig_id?(json, "https://www.w3.org/ns/activitystreams#replies"),
        to: to = dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        cc: cc = dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        summary: dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        content: dig?(json, "https://www.w3.org/ns/activitystreams#content", "und"),
        media_type: dig?(json, "https://www.w3.org/ns/activitystreams#mediaType"),
        attachments: dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
          url = attachment.dig?("https://www.w3.org/ns/activitystreams#url").try(&.as_s)
          media_type = attachment.dig?("https://www.w3.org/ns/activitystreams#mediaType").try(&.as_s)
          Attachment.new(url, media_type) if url && media_type
        end,
        urls: dig_ids?(json, "https://www.w3.org/ns/activitystreams#url"),
        # use addressing to establish visibility
        visible: [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public")
      }
    end
  end
end
