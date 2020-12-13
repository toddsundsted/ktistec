require "json"

require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"
require "../activity_pub/actor"

module ActivityPub
  class Object
    include Ktistec::Model(Common, Deletable, Polymorphic, Serialized, Linked)

    @@table_name = "objects"

    def local
      iri.starts_with?(Ktistec.host)
    end

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

    @[Persistent]
    property attachments : Array(Attachment)?

    @[Persistent]
    property urls : Array(String)?

    def display_link
      urls.try(&.first?) || iri
    end

    def display_date
      published.try(&.to_local) || created_at.to_local
    end

    struct Source
      include JSON::Serializable

      property content : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      def initialize(@content, @media_type)
      end
    end

    struct Attachment
      include JSON::Serializable

      property url : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      def initialize(@url, @media_type)
      end

      def image?
        media_type.in?(%w[image/bmp image/gif image/jpeg image/png image/svg+xml image/x-icon image/apng image/webp])
      end

      def video?
        media_type.in?(%w[video/mp4 video/webm video/ogg])
      end

      def audio?
        media_type.in?(%w[audio/mp4 audio/webm audio/ogg audio/flac])
      end
    end

    @[Assignable]
    property depth : Int32 { 0 }

    def thread
      {% begin %}
        {% vs = ActivityPub::Object.instance_vars.select(&.annotation(Persistent)) %}
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
           replies_to(iri, depth) AS (
              SELECT * FROM (SELECT iri, 0 FROM ancestors_of ORDER BY depth DESC LIMIT 1)
                 UNION
                SELECT o.iri, r.depth + 1 AS depth
                  FROM objects AS o, replies_to AS r
                 WHERE o.in_reply_to_iri = r.iri
              ORDER BY depth DESC
            )
        SELECT {{ vs.map{ |v| "o.\"#{v}\"" }.join(",").id }}, r.depth
          FROM objects AS o, replies_to AS r
         WHERE o.iri IN (r.iri) AND o.deleted_at IS NULL
        QUERY
        Array(Object).new.tap do |array|
          Ktistec.database.query(
            query, self.iri
          ) do |rs|
            rs.each do
              attrs = {
               {% for v in vs %}
                 {{v}}: rs.read({{v.type}}),
               {% end %}
               depth: rs.read(Int32)
              }
              array <<
                case attrs[:type]
                {% for subclass in ActivityPub::Object.all_subclasses %}
                  when {{name = subclass.stringify}}
                    {{subclass}}.new(**attrs)
                {% end %}
                else
                  ActivityPub::Object.new(**attrs)
                end
            end
          end
        end
      {% end %}
    end

    def ancestors
      {% begin %}
        {% vs = ActivityPub::Object.instance_vars.select(&.annotation(Persistent)) %}
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
        SELECT {{ vs.map{ |v| "o.\"#{v}\"" }.join(",").id }}, a.depth
          FROM objects AS o, ancestors_of AS a
         WHERE o.iri IN (a.iri) AND o.deleted_at IS NULL
        QUERY
        Array(Object).new.tap do |array|
          Ktistec.database.query(
            query, self.iri
          ) do |rs|
            rs.each do
              attrs = {
               {% for v in vs %}
                 {{v}}: rs.read({{v.type}}),
               {% end %}
               depth: rs.read(Int32)
              }
              array <<
                case attrs[:type]
                {% for subclass in ActivityPub::Object.all_subclasses %}
                  when {{name = subclass.stringify}}
                    {{subclass}}.new(**attrs)
                {% end %}
                else
                  ActivityPub::Object.new(**attrs)
                end
            end
          end
        end
      {% end %}
    end

    def to_json_ld(recursive = false)
      object = self
      render "src/views/objects/object.json.ecr"
    end

    def self.from_json_ld(json)
      ActivityPub.from_json_ld(json, default: self).as(self)
    end

    def self.from_json_ld?(json)
      ActivityPub.from_json_ld?(json, default: self).as(self?)
    rescue TypeCastError
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
