require "../../framework/model"
require "json"

module ActivityPub
  class Object
    include Balloon::Model(Common, Polymorphic, Serialized)
    extend Balloon::Util

    @@table_name = "objects"

    def self.find(_iri iri : String?)
      find(iri: iri)
    end

    def self.find?(_iri iri : String?)
      find?(iri: iri)
    end

    def self.dereference?(iri : String?) : self?
      if iri
        unless (object = self.find?(iri))
          unless iri.starts_with?(Balloon.host)
            self.open?(iri) do |response|
              object = self.from_json_ld?(response.body)
            end
          end
        end
      end
      object
    end

    @[Persistent]
    property iri : String { "" }
    validates(iri) { unique_absolute_uri?(iri) }

    private def unique_absolute_uri?(iri)
      if iri.blank?
        "must be present"
      elsif !URI.parse(iri).absolute?
        "must be an absolute URI"
      elsif (object = Object.find?(iri)) && object.id != self.id
        "must be unique"
      end
    end

    def local
      iri.starts_with?(Balloon.host)
    end

    @[Persistent]
    property visible : Bool { false }
    validates(visible) do
      "may not be true" unless !visible || local
    end

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
      json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        iri: json.dig?("@id").try(&.as_s),
        _type: json.dig?("@type").try(&.as_s.split("#").last),
        published: (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        attributed_to_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#attributedTo"),
        in_reply_to_iri: dig_id?(json, "https://www.w3.org/ns/activitystreams#inReplyTo"),
        replies: dig_id?(json, "https://www.w3.org/ns/activitystreams#replies"),
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
