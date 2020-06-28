require "../../framework/model"
require "json"

module ActivityPub
  class Object
    include Balloon::Model(Common, Polymorphic, Serialized)

    @@table_name = "objects"

    def self.find(_iri iri : String?)
      find(iri: iri)
    end

    def self.find?(_iri iri : String?)
      find?(iri: iri)
    end

    @[Persistent]
    property iri : String?
    validates(iri) { unique_absolute_uri?(iri) }

    private def unique_absolute_uri?(iri)
      if iri.nil?
        "must be present"
      elsif !URI.parse(iri).absolute?
        "must be an absolute URI"
      elsif (object = Object.find?(iri)) && object.id != self.id
        "must be unique"
      end
    end

    @[Persistent]
    property visible : Bool { false }
    validates(visible) do
      "may not be true" unless !visible || iri.try(&.starts_with?(Balloon.host))
    end

    @[Persistent]
    property published : Time?

    @[Persistent]
    property in_reply_to : String?

    @[Persistent]
    property replies : String?

    @[Persistent]
    property attributed_to : Array(String)?

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

    struct Source
      include JSON::Serializable

      property content : String
      property media_type : String

      def initialize(@content, @media_type)
      end
    end

    struct Attachment
      include JSON::Serializable

      property url : String
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

    def self.from_json_ld(json)
      self.new(**map(json))
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json)
      json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
      {
        iri: json.dig?("@id").try(&.as_s),
        published: (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_iso8601(p) : nil,
        in_reply_to: dig_id?(json, "https://www.w3.org/ns/activitystreams#inReplyTo"),
        replies: dig_id?(json, "https://www.w3.org/ns/activitystreams#replies"),
        attributed_to: dig_ids?(json, "https://www.w3.org/ns/activitystreams#attributedTo"),
        to: dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        cc: dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        summary: dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        content: dig?(json, "https://www.w3.org/ns/activitystreams#content", "und"),
        media_type: dig?(json, "https://www.w3.org/ns/activitystreams#mediaType"),
        source: dig_value?(json, "https://www.w3.org/ns/activitystreams#source") do |source|
          content = dig?(source, "https://www.w3.org/ns/activitystreams#content", "und")
          media_type = dig?(source, "https://www.w3.org/ns/activitystreams#mediaType")
          Source.new(content, media_type) if content && media_type
        end,
        attachments: dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
          url = attachment.dig?("https://www.w3.org/ns/activitystreams#url").try(&.as_s)
          media_type = attachment.dig?("https://www.w3.org/ns/activitystreams#mediaType").try(&.as_s)
          Attachment.new(url, media_type) if url && media_type
        end,
        urls: dig_ids?(json, "https://www.w3.org/ns/activitystreams#url")
      }
    end
  end
end
