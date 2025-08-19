require "yaml"
require "log"

# Model Context Protocol (MCP) prompt.
#
class Prompt
  include YAML::Serializable
  include YAML::Serializable::Strict

  Log = ::Log.for(self)

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
    include YAML::Serializable::Strict

    getter name : String
    getter title : String?
    getter description : String?
    getter required : Bool

    def initialize(@name : String, @title : String? = nil, @description : String? = nil, @required : Bool = false)
    end
  end

  struct Content
    include YAML::Serializable
    include YAML::Serializable::Strict

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
    include YAML::Serializable::Strict

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

  @@cached_prompts : Array(Prompt) = [] of Prompt
  @@cache_timestamp : Time = Time::UNIX_EPOCH

  # Returns all prompts.
  #
  # Load prompts if cache is empty or outdated.
  #
  def self.all : Array(Prompt)
    current_mtime = get_directory_mtime

    if current_mtime && current_mtime > @@cache_timestamp
      @@cached_prompts = load_prompts
      @@cache_timestamp = current_mtime
    end

    @@cached_prompts
  end

  # Gets the latest modification time of all YAML files in the
  # prompts directory.
  #
  # Returns `nil` if the directory does not exist or is empty.
  #
  private def self.get_directory_mtime : Time?
    prompts_dir = default_prompts_dir

    if Dir.exists?(prompts_dir)
      Dir.glob(File.join(prompts_dir, "*.yml"))
        .map { |f| File.info(f).modification_time }
        .max?
    end
  end

  # Loads prompts.
  #
  # Returns prompts ordered by file modification time.
  #
  private def self.load_prompts : Array(Prompt)
    prompts_dir = default_prompts_dir

    prompts = [] of Prompt

    if Dir.exists?(prompts_dir)
      Dir.glob(File.join(prompts_dir, "*.yml"))
        .sort_by { |f| File.info(f).modification_time }
        .each do |file_path|
          begin
            yaml = File.read(file_path)
            prompts << Prompt.from_yaml(yaml)
          rescue ex
            Log.warn { "Failed to load prompt #{file_path}: #{ex.message}" }
          end
      end
    end

    prompts
  end

  private def self.default_prompts_dir : String
    File.join(Dir.current, "etc", "prompts")
  end
end
