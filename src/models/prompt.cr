require "yaml"
require "log"

# Model Context Protocol (MCP) prompt.
#
class Prompt
  include YAML::Serializable

  enum Role
    User
    Assistant

    def to_yaml(yaml : YAML::Nodes::Builder) : Nil
      yaml.scalar(self.to_s.downcase)
    end
  end

  enum ContentType
    Text
    Image
    Resource

    def to_yaml(yaml : YAML::Nodes::Builder) : Nil
      yaml.scalar(self.to_s.downcase)
    end
  end

  struct Argument
    include YAML::Serializable

    getter name : String
    getter title : String?
    getter description : String?
    getter required : Bool

    def initialize(@name : String, @title : String? = nil, @description : String? = nil, @required : Bool = false)
    end
  end

  struct Content
    include YAML::Serializable

    getter type : ContentType
    getter text : String?
    getter data : String?
    @[YAML::Field(key: "mimeType")]
    getter mime_type : String?

    def initialize(@type = ContentType::Text, @text : String? = nil, @data : String? = nil, @mime_type : String? = nil)
    end
  end

  struct Message
    include YAML::Serializable

    getter role : Role
    getter content : Content

    def initialize(@role = Role::User, @content = Content.new)
    end
  end

  getter name : String
  getter title : String?
  getter description : String?
  getter arguments : Array(Argument)
  getter messages : Array(Message)

  def initialize(@name : String, @title : String? = nil, @description : String? = nil, @arguments = [] of Argument, @messages = [] of Message)
  end
end
