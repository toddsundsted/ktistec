require "./errors"
require "../utils/json_rpc"
require "../utils/paths"
require "../models/account"
require "../models/relationship/social/follow"
require "../models/relationship/content/notification/follow/hashtag"
require "../models/relationship/content/notification/follow/mention"
require "../models/relationship/content/notification/follow/thread"
require "../models/relationship/content/notification/poll/expiry"
require "../models/tag/hashtag"
require "../models/tag/mention"
require "./tools/results_pager"
require "./resources"

module MCP
  module Tools
    include Utils::Paths

    Log = ::Log.for("mcp")

    class_property result_pager = ResultsPager(JSON::Any).new

    alias ToolPropertyDefinition =
      NamedTuple(
        name: String,
        type: String,
        description: String,
        required: Bool,
        matches: Regex?,
        minimum: Int32?,
        maximum: Int32?,
        default: String | Int32 | Bool | Time | Array(String) | Array(Int32) | Array(Bool) | Nil,
        enum: Array(String)?,     # enum values for string types
        # array-specific properties
        items: String?,           # type of array items ("string", "integer")
        min_items: Int32?,        # minimum array length
        max_items: Int32?,        # maximum array length
        unique_items: Bool?,      # whether array elements must be unique
      )

    alias ToolDefinition =
      NamedTuple(
        name: String,
        description: String,
        properties: Array(ToolPropertyDefinition),
      )

    TOOL_DEFINITIONS = [] of ToolDefinition

    # Defines an MCP tool.
    #
    # Arguments:
    # - name: Tool name
    # - description: Tool description
    # - properties: Array of ToolPropertyDefinition (type, description, required, etc.)
    # - block: Tool implementation
    #
    # The block can access validated parameters via `arguments["param_name"]?`
    # and must return `JSON::Any`.
    #
    macro def_tool(name, description, properties = [] of ToolPropertyDefinition, &block)
      {% TOOL_DEFINITIONS << {name: name, description: description, properties: properties} %}

      def MCP::Tools.handle_tool_{{name.id}}(params : JSON::Any, account : Account) : JSON::Any
        unless (arguments = params["arguments"]?)
          raise MCPError.new("Missing arguments", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        missing_fields = [] of String
        {% for prop in properties %}
          {% if prop[:required] %}
            missing_fields << {{prop[:name]}} unless arguments[{{prop[:name]}}]?
          {% end %}
        {% end %}
        unless missing_fields.empty?
          raise MCPError.new("Missing #{missing_fields.join(", ")}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        {% for prop in properties %}
          if (value = arguments[{{prop[:name]}}]?)
            {% if prop[:type] == "integer" %}
              unless value.raw.is_a?(Int32) || value.raw.is_a?(Int64)
                raise MCPError.new("`#{{{prop[:name]}}}` must be an integer", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "boolean" %}
              unless value.raw.is_a?(Bool)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a boolean", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "string" %}
              unless value.raw.is_a?(String)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a string", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "time" %}
              unless value.raw.is_a?(String)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a RFC3339 timestamp", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "array" %}
              unless value.raw.is_a?(Array)
                raise MCPError.new("`#{{{prop[:name]}}}` must be an array", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% end %}
          end
        {% end %}

        {% for prop in properties %}
          {% if prop[:type] == "integer" %}
            if (value = arguments[{{prop[:name]}}]?)
              int_value = value.as_i
              {% if prop[:minimum] %}
                if int_value < {{prop[:minimum]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` must be >= {{prop[:minimum]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
              {% if prop[:maximum] %}
                if int_value > {{prop[:maximum]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` must be <= {{prop[:maximum]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
            end
          {% elsif prop[:type] == "string" && prop[:matches] %}
            if (value = arguments[{{prop[:name]}}]?)
              string_value = value.as_s
              unless {{prop[:matches]}}.match(string_value)
                raise MCPError.new("`#{{{prop[:name]}}}` format is invalid", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            end
          {% elsif prop[:type] == "time" %}
            if (value = arguments[{{prop[:name]}}]?)
              time_string = value.as_s
              begin
                Time.parse_rfc3339(time_string)
              rescue
                raise MCPError.new("`#{{{prop[:name]}}}` must be a RFC3339 timestamp", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            end
          {% elsif prop[:type] == "array" %}
            if (value = arguments[{{prop[:name]}}]?)
              array_value = value.as_a

              {% if prop[:min_items] %}
                if array_value.size < {{prop[:min_items]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` size must be >= {{prop[:min_items]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
              {% if prop[:max_items] %}
                if array_value.size > {{prop[:max_items]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` size must be <= {{prop[:max_items]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}

              {% if prop[:items] %}
                array_value.each_with_index do |item, index|
                  {% if prop[:items] == "string" %}
                    unless item.raw.is_a?(String)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be a string", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% elsif prop[:items] == "integer" %}
                    unless item.raw.is_a?(Int32) || item.raw.is_a?(Int64)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be an integer", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% elsif prop[:items] == "boolean" %}
                    unless item.raw.is_a?(Bool)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be a boolean", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% end %}
                end
              {% end %}

              {% if prop[:unique_items] %}
                string_items = array_value.map(&.to_s)
                if string_items.size != string_items.uniq.size
                  raise MCPError.new("`#{{{prop[:name]}}}` items must be unique", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
            end
          {% end %}
        {% end %}

        {% for prop in properties %}
            {{prop[:name].id}} =
          {% if prop[:required] %} \
            {% if prop[:type] == "string" %}
              arguments[{{prop[:name]}}].as_s
            {% elsif prop[:type] == "integer" %}
              arguments[{{prop[:name]}}].as_i
            {% elsif prop[:type] == "boolean" %}
              arguments[{{prop[:name]}}].as_bool
            {% elsif prop[:type] == "time" %}
              Time.parse_rfc3339(arguments[{{prop[:name]}}].as_s)
            {% elsif prop[:type] == "array" %}
              {% if prop[:items] == "string" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_s)
              {% elsif prop[:items] == "integer" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_i)
              {% elsif prop[:items] == "boolean" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_bool)
              {% else %}
                arguments[{{prop[:name]}}].as_a
              {% end %}
            {% end %}
          {% else %}
            {% if prop[:type] == "string" %}
              arguments[{{prop[:name]}}]?.try(&.as_s) || {{prop[:default]}}
            {% elsif prop[:type] == "integer" %}
              arguments[{{prop[:name]}}]?.try(&.as_i) || {{prop[:default]}}
            {% elsif prop[:type] == "boolean" %}
              arguments[{{prop[:name]}}]?.try(&.as_bool) || {{prop[:default]}}
            {% elsif prop[:type] == "time" %}
              arguments[{{prop[:name]}}]? ? Time.parse_rfc3339(arguments[{{prop[:name]}}].as_s) : {{prop[:default]}}
            {% elsif prop[:type] == "array" %}
              {% if prop[:items] == "string" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_s)) || {{prop[:default]}}
              {% elsif prop[:items] == "integer" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_i)) || {{prop[:default]}}
              {% elsif prop[:items] == "boolean" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_bool)) || {{prop[:default]}}
              {% else %}
                arguments[{{prop[:name]}}]?.try(&.as_a) || {{prop[:default]}}
              {% end %}
            {% end %}
          {% end %}
        {% end %}

        {% if block %}
            {{block.body}}
        {% else %}
            {
              {% for prop in properties %}
                {{prop[:name].id}}: {{prop[:name].id}},
              {% end %}
            }
        {% end %}
      end
    end

    NAME_REGEX = /^([a-zA-Z0-9_-]+|hashtag#[a-zA-Z0-9_-]+|mention@[a-zA-Z0-9_@.-]+)$/

    def_tool(
      "paginate_collection",
      "Paginate through collections of ActivityPub objects, activities, and actors. Use this tool when you want to inspect the contents of a collection.", [
        {name: "name", type: "string", description: "Name of the collection to paginate", required: true, matches: NAME_REGEX},
        {name: "page", type: "integer", description: "Page number (optional, defaults to 1)", minimum: 1, default: 1},
        {name: "size", type: "integer", description: "Number of items per page (optional, defaults to 10, maximum 1000)", minimum: 1, maximum: 20, default: 10},
    ]) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "paginate_collection: user=#{mcp_user_path(account)} collection=#{name} page=#{page} size=#{size}" }

      actor = account.actor

      objects, more =
        case name
        when "notifications"
          notifications = actor.notifications(page: page, size: size)
          objects = notifications.map do |notification|
            notification_to_json_any(notification)
          end
          {objects.compact, notifications.more?}
        when "timeline"
          timeline = actor.timeline(page: page, size: size)
          objects = timeline.map do |rel|
            JSON::Any.new(MCP::Resources.object_contents(rel.object))
          end
          {objects, timeline.more?}
        when "posts"
          posts = actor.all_posts(page: page, size: size)
          objects = posts.map do |post|
            JSON::Any.new(MCP::Resources.object_contents(post))
          end
          {objects, posts.more?}
        when "drafts"
          drafts = actor.drafts(page: page, size: size)
          objects = drafts.map do |draft|
            JSON::Any.new(MCP::Resources.object_contents(draft))
          end
          {objects, drafts.more?}
        when "likes"
          likes = actor.likes(page: page, size: size)
          objects = likes.map do |liked_object|
            JSON::Any.new(MCP::Resources.object_contents(liked_object))
          end
          {objects, likes.more?}
        when "dislikes"
          dislikes = actor.dislikes(page: page, size: size)
          objects = dislikes.map do |disliked_object|
            JSON::Any.new(MCP::Resources.object_contents(disliked_object))
          end
          {objects, dislikes.more?}
        when "announces"
          announces = actor.announces(page: page, size: size)
          objects = announces.map do |announced_object|
            JSON::Any.new(MCP::Resources.object_contents(announced_object))
          end
          {objects, announces.more?}
        when "bookmarks"
          bookmarks = actor.bookmarks(page: page, size: size)
          objects = bookmarks.map do |bookmarked_object|
            JSON::Any.new(MCP::Resources.object_contents(bookmarked_object))
          end
          {objects, bookmarks.more?}
        when "pins"
          pins = actor.pins(page: page, size: size)
          objects = pins.map do |pinned_object|
            JSON::Any.new(MCP::Resources.object_contents(pinned_object))
          end
          {objects, pins.more?}
        when "followers"
          followers = Relationship::Social::Follow.followers_for(actor.iri, page: page, size: size)
          objects = followers.map do |relationship|
            follower = relationship.actor
            JSON::Any.new({
              "actor_id" => JSON::Any.new(follower.id),
              "actor_handle" => JSON::Any.new(follower.handle),
              "confirmed" => JSON::Any.new(relationship.confirmed)
            })
          end
          {objects, followers.more?}
        when "following"
          following = Relationship::Social::Follow.following_for(actor.iri, page: page, size: size)
          objects = following.map do |relationship|
            followed = relationship.object
            JSON::Any.new({
              "actor_id" => JSON::Any.new(followed.id),
              "actor_handle" => JSON::Any.new(followed.handle),
              "confirmed" => JSON::Any.new(relationship.confirmed)
            })
          end
          {objects, following.more?}
        else
          if name.starts_with?("hashtag#")
            hashtag = name.sub("hashtag#", "")
            hashtag_objects = Tag::Hashtag.all_objects(hashtag, page: page, size: size)
            objects = hashtag_objects.map do |obj|
              JSON::Any.new(MCP::Resources.object_contents(obj))
            end
            {objects, hashtag_objects.more?}
          elsif name.starts_with?("mention@")
            mention = name.sub("mention@", "")
            mention_objects = Tag::Mention.all_objects(mention, page: page, size: size)
            objects = mention_objects.map do |obj|
              JSON::Any.new(MCP::Resources.object_contents(obj))
            end
            {objects, mention_objects.more?}
          else
            raise MCPError.new("`#{name}` unsupported", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
        end

      result_data = {
        "objects" => objects.to_a,
        "more" => more,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    def_tool(
      "count_collection_since",
      "Count items in ActivityPub collections since a given time. Use this tool when you want to know if new items have been added in the last day/week/month.", [
        {name: "name", type: "string", description: "Name of the collection to count", required: true, matches: NAME_REGEX},
        {name: "since", type: "time", description: "Time (RFC3339) to count from", required: true},
    ]) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "count_collection_since: user=#{mcp_user_path(account)} collection=#{name} since=#{since}" }

      current_time = Time.utc
      actor = account.actor

      count =
        case name
        when "notifications"
          actor.notifications(since: since)
        when "timeline"
          actor.timeline(since: since)
        when "posts"
          actor.all_posts(since: since)
        when "drafts"
          actor.drafts(since: since)
        when "likes"
          actor.likes(since: since)
        when "dislikes"
          actor.dislikes(since: since)
        when "announces"
          actor.announces(since: since)
        when "bookmarks"
          actor.bookmarks(since: since)
        when "pins"
          actor.pins(since: since)
        when "followers"
          Relationship::Social::Follow.followers_since(actor.iri, since)
        when "following"
          Relationship::Social::Follow.following_since(actor.iri, since)
        else
          if name.starts_with?("hashtag#")
            hashtag = name.sub("hashtag#", "")
            Tag::Hashtag.all_objects(hashtag, since)
          elsif name.starts_with?("mention@")
            mention = name.sub("mention@", "")
            Tag::Mention.all_objects(mention, since)
          else
            raise MCPError.new("`#{name}` unsupported", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
        end

      result_data = {
        "counted_at" => current_time.to_rfc3339,
        "count" => count,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    record ThreadQueryResult,
      objects_data : Array(JSON::Any),
      objects_count : Int32,
      authors_count : Int32?,
      root_object_id : Int64?,
      max_depth : Int32

    def_tool(
      "get_thread",
      "Retrieve thread structure, metadata, and summary data. Large threads may have " \
      "hundreds of objects, so this tool supports pagination. This tool retrieves the " \
      "entire thread for the given `object_id` starting at the root, not only the " \
      "subthread.\n\n" \
      "**Two Modes of Operation:**\n\n" \
      "1. **Initial Query Mode**: Provide `object_id` (plus optional `projection` and `page_size`) to start traversing a thread.\n" \
      "   Returns summary data and the first page of objects. If there are more pages, includes a `cursor`.\n\n" \
      "2. **Pagination Mode**: Provide only `cursor` (from a previous response) to fetch the next page.\n" \
      "   Returns the next page of objects. If there are more pages, includes a `cursor`.\n" \
      "   Do not include `object_id`, `projection`, or `page_size`.\n\n" \
      "**Usage Examples:**\n" \
      "- Start: `{\"object_id\": 123, \"projection\": \"metadata\", \"page_size\": 20}`\n" \
      "- Continue: `{\"cursor\": \"eyJwYWdlcl9pZ...\"}`\n\n" \
      "**Important:** You must provide EITHER `object_id` OR `cursor`, but not both.",
      [
        {name: "object_id", type: "integer", description: "Database ID of any object in the thread. Required for initial query, omit when using cursor.", required: false, minimum: 1},
        {name: "projection", type: "string", description: "Data fields to include: 'minimal' (IDs and structure only) or 'metadata' (adds authors, timestamps). Only used with object_id.", required: false, enum: ["minimal", "metadata"], default: "metadata"},
        {name: "page_size", type: "integer", description: "Number of objects per page. Only used with object_id.", required: false, minimum: 1, maximum: 100, default: 25},
        {name: "cursor", type: "string", description: "Opaque pagination cursor from previous get_thread response. Use ONLY this parameter to fetch next page.", required: false},
      ]
    ) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      has_object_id = arguments["object_id"]?
      has_cursor = arguments["cursor"]?

      if has_object_id && has_cursor
        raise MCPError.new("Cannot provide both 'object_id' and 'cursor'.", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless has_object_id || has_cursor
        raise MCPError.new("Must provide either 'object_id' or 'cursor'.", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      # PAGINATION MODE
      if (cursor = arguments["cursor"]?.try(&.as_s))
        Log.debug { "get_thread (pagination): user=#{mcp_user_path(account)} cursor=#{cursor[0..8]}..." }

        pager_response = @@result_pager.fetch(cursor)
        page_objects = pager_response[:page]
        next_cursor = pager_response[:cursor]

        result_data = {
          "objects" => page_objects,
          "cursor" => next_cursor,
          "has_more" => !!next_cursor,
        }

      # INITIAL QUERY MODE
      else
        object_id = arguments["object_id"].as_i64
        projection = arguments["projection"]?.try(&.as_s) || "metadata"
        page_size = arguments["page_size"]?.try(&.as_i) || 25

        unless (object = ActivityPub::Object.find?(object_id))
          raise MCPError.new("Object not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end
        unless ["minimal", "metadata"].includes?(projection)
          raise MCPError.new("Projection must be 'minimal' or 'metadata'", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        Log.debug { "get_thread (initial query): user=#{mcp_user_path(account)} object_id=#{object_id} projection=#{projection}" }

        query_result =
          case projection
          when "minimal"
            results = object.thread_query(projection: ActivityPub::Object::PROJECTION_MINIMAL)
            objects = results.map do |tuple|
              thread_obj = ActivityPub::Object.find(tuple[:id])
              hash = {} of String => JSON::Any
              hash["object_id"] = JSON::Any.new(tuple[:id])
              hash["iri"] = JSON::Any.new(tuple[:iri])
              hash["parent_id"] = JSON::Any.new(thread_obj.in_reply_to?.try(&.id))
              hash["thread"] = JSON::Any.new(tuple[:thread])
              hash["depth"] = JSON::Any.new(tuple[:depth])
              JSON::Any.new(hash)
            end
            ThreadQueryResult.new(
              objects_data: objects,
              objects_count: objects.size,
              authors_count: nil,
              root_object_id: results.find { |t| t[:in_reply_to_iri].nil? }.try(&.[:id]),
              max_depth: results.max_of? { |t| t[:depth] } || 0
            )
          when "metadata"
            results = object.thread_query(projection: ActivityPub::Object::PROJECTION_METADATA)
            objects = results.map do |tuple|
              thread_obj = ActivityPub::Object.find(tuple[:id])
              hash = {} of String => JSON::Any
              hash["object_id"] = JSON::Any.new(tuple[:id])
              hash["iri"] = JSON::Any.new(tuple[:iri])
              if tuple[:attributed_to_iri] && (attributed_to = thread_obj.attributed_to?)
                hash["actor"] = JSON::Any.new({
                  "id" => JSON::Any.new(attributed_to.id),
                  "handle" => JSON::Any.new(attributed_to.handle)
                })
              else
                hash["actor"] = JSON::Any.new(nil)
              end
              hash["parent_id"] = JSON::Any.new(thread_obj.in_reply_to?.try(&.id))
              hash["thread"] = JSON::Any.new(tuple[:thread])
              hash["published"] = JSON::Any.new(tuple[:published].try(&.to_rfc3339))
              hash["deleted"] = JSON::Any.new(tuple[:deleted])
              hash["blocked"] = JSON::Any.new(tuple[:blocked])
              hash["hashtags"] = JSON::Any.new(tuple[:hashtags])
              hash["mentions"] = JSON::Any.new(tuple[:mentions])
              hash["depth"] = JSON::Any.new(tuple[:depth])
              JSON::Any.new(hash)
            end
            ThreadQueryResult.new(
              objects_data: objects,
              objects_count: objects.size,
              authors_count: results.compact_map { |t| t[:attributed_to_iri] }.uniq.size,
              root_object_id: results.find { |t| t[:in_reply_to_iri].nil? }.try(&.[:id]),
              max_depth: results.max_of? { |t| t[:depth] } || 0
            )
          else
            raise "should never happen"
          end

        pager_response = @@result_pager.store(query_result.objects_data, page_size)
        page_objects = pager_response[:page]
        cursor_value = pager_response[:cursor]

        result_data = {
          "objects" => page_objects,
          "cursor" => cursor_value,
          "has_more" => !!cursor_value,
          "projection" => projection,
          "page_size" => page_size,
          "objects_count" => query_result.objects_count,
          "authors_count" => query_result.authors_count,
          "root_object_id" => query_result.root_object_id,
          "max_depth" => query_result.max_depth,
        }
      end

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    # Formats time ranges as RFC3339 strings.
    #
    private def self.format_time_range(time_range : Tuple(Time?, Time?)?)
      if time_range && (start_time = time_range[0]) && (end_time = time_range[1])
        [start_time.to_rfc3339, end_time.to_rfc3339]
      else
        [nil, nil]
      end
    end

    def_tool(
      "analyze_thread",
      "Analyze thread structure and identify key participants and notable branches. " \
      "Use this before reading thread content to understand the conversation landscape " \
      "and identify which posts are most relevant to examine. This is especially " \
      "useful with large threads.\n\n" \
      "**Returns:**\n" \
      "- Basic statistics (total posts, unique authors, max depth, analysis duration)\n" \
      "- Key participants (original poster + top 5 most active posters with their posts)\n" \
      "- Notable branches (conversation subtrees with ≥5 posts)\n" \
      "- Timeline histogram (temporal distribution of posts)",
      [
        {name: "object_id", type: "integer", description: "Database ID of any object in the thread", required: true, minimum: 1},
      ]
    ) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      unless (thread_object = ActivityPub::Object.find?(object_id))
        raise MCPError.new("Object not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "analyze_thread: user=#{mcp_user_path(account)} object_id=#{object_id}" }

      analysis = thread_object.analyze_thread(for_actor: account.actor)

      result = {
        "thread_id" => analysis.thread_id,
        "object_count" => analysis.object_count,
        "author_count" => analysis.author_count,
        "root_object_id" => analysis.root_object_id,
        "max_depth" => analysis.max_depth,
        "duration_ms" => analysis.duration_ms,

        "key_participants" => analysis.key_participants.map do |p|
          actor = ActivityPub::Actor.find?(iri: p.actor_iri)
          {
            "actor" => {
              "id" => actor ? actor.id : nil,
              "handle" => actor ? actor.handle : nil,
            },
            "object_count" => p.object_count,
            "depth_range" => [p.depth_range[0], p.depth_range[1]],
            "time_range" => format_time_range(p.time_range),
            "object_ids" => p.object_ids,
          }
        end,

        "notable_branches" => analysis.notable_branches.map do |b|
          {
            "root_id" => b.root_id,
            "root_preview" => (preview = ActivityPub::Object.find(b.root_id).preview) && Ktistec::Util.render_as_text_and_truncate(preview, 120),
            "object_count" => b.object_count,
            "author_count" => b.author_count,
            "depth_range" => [b.depth_range[0], b.depth_range[1]],
            "time_range" => format_time_range(b.time_range),
            "object_ids" => b.object_ids,
          }
        end,

        "timeline_histogram" => if (histogram = analysis.timeline_histogram)
          {
            "time_range" => format_time_range(histogram.time_range),
            "total_objects" => histogram.total_objects,
            "outliers_excluded" => histogram.outliers_excluded,
            "bucket_size_minutes" => histogram.bucket_size_minutes,
            "buckets" => histogram.buckets.map do |bucket|
              {
                "time_range" => format_time_range(bucket.time_range),
                "object_count" => bucket.object_count,
                "cumulative_count" => bucket.cumulative_count,
                "author_count" => bucket.author_count,
                "object_ids" => bucket.object_ids,
              }
            end
          }
        end,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result.to_json)
        })])
      })
    end

    def_tool(
      "read_resources",
      "Read one or more resources by URI (format \"ktistec://{resource}/{id*}\"). Supports all resource types including " \
      "templated resources (actors, objects) and static resources (information, users). Supports batched reads (comma-separated " \
      "IDs of resources of the same type). Use this tool as a universal fallback when resources are not supported by an MCP " \
      "client.", [
        {name: "uris", type: "array", description: "Resource URIs to read (e.g., ['ktistec://actors/123,456', 'ktistec://objects/456,789'])", required: true, items: "string"},
    ]) do
      Log.debug { "read_resources: user=#{mcp_user_path(account)} uris=#{uris}" }

      resources_data = uris.map do |uri|

        # NOTE: create a fake JSON::RPC::Request to reuse existing resource reading logic
        fake_params = JSON::Any.new({
          "uri" => JSON::Any.new(uri)
        })
        fake_request = JSON::RPC::Request.new(
          "resources/read",
          "fake-id",
          fake_params
        )

        # reuse existing handle_resources_read logic
        result = MCP::Resources.handle_resources_read(fake_request, account)
        contents = result["contents"].as_a

        # extract the resource data from each content item
        contents.map do |content|
          resource_data = JSON.parse(content["text"].as_s)
          {
            "uri" => content["uri"],
            "data" => resource_data
          }
        end
      end.flatten

      result_data = {
        "resources" => resources_data,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    def self.handle_tools_list(request : JSON::RPC::Request) : JSON::Any
      {% begin %}
      tools = [
        {% for tool in TOOL_DEFINITIONS %}
          JSON::Any.new({
            "name" => JSON::Any.new({{tool[:name]}}),
            "description" => JSON::Any.new({{tool[:description]}}),
            {% if tool[:raw_schema_json] %}
              "inputSchema" => JSON.parse({{tool[:raw_schema_json]}}),
            {% else %}
              "inputSchema" => JSON::Any.new({
                "type" => JSON::Any.new("object"),
                "properties" => JSON::Any.new({
                  {% for prop in tool[:properties] %}
                    {% if prop[:type] == "array" %}
                      {{prop[:name]}} => JSON::Any.new({
                        "type" => JSON::Any.new("array"),
                        "description" => JSON::Any.new({{prop[:description]}}),
                        {% if prop[:items] %}
                          "items" => JSON::Any.new({
                            "type" => JSON::Any.new({{prop[:items]}})
                          }),
                        {% end %}
                        {% if prop[:min_items] %}
                          "minItems" => JSON::Any.new({{prop[:min_items]}}),
                        {% end %}
                        {% if prop[:max_items] %}
                          "maxItems" => JSON::Any.new({{prop[:max_items]}}),
                        {% end %}
                        {% if prop[:unique_items] %}
                          "uniqueItems" => JSON::Any.new({{prop[:unique_items]}}),
                        {% end %}
                      }),
                    {% else %}
                      {{prop[:name]}} => JSON::Any.new({
                        "type" => JSON::Any.new({{prop[:type] == "time" ? "string" : prop[:type]}}),
                        "description" => JSON::Any.new({{prop[:description]}}),
                        {% if prop[:minimum] %}
                          "minimum" => JSON::Any.new({{prop[:minimum]}}),
                        {% end %}
                        {% if prop[:maximum] %}
                          "maximum" => JSON::Any.new({{prop[:maximum]}}),
                        {% end %}
                        {% if prop[:enum] %}
                          "enum" => JSON::Any.new([
                            {% for value in prop[:enum] %}
                              JSON::Any.new({{value}}),
                            {% end %}
                          ]),
                        {% end %}
                      }),
                    {% end %}
                  {% end %}
                }),
                "required" => JSON::Any.new([
                  {% for prop in tool[:properties] %}
                    {% if prop[:required] %}
                      JSON::Any.new({{prop[:name]}}),
                    {% end %}
                  {% end %}
                ] of JSON::Any)
              }),
            {% end %}
          }),
        {% end %}
      ]

      JSON::Any.new({
        "tools" => JSON::Any.new(tools)
      })
      {% end %}
    end

    def self.handle_tools_call(request : JSON::RPC::Request, account : Account) : JSON::Any
      unless (params = request.params)
        raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (name = params["name"]?.try(&.as_s))
        raise MCPError.new("Missing tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "calling tool: #{name}" }

      case name
      when "paginate_collection"
        handle_tool_paginate_collection(params, account)
      when "count_collection_since"
        handle_tool_count_collection_since(params, account)
      when "get_thread"
        handle_tool_get_thread(params, account)
      when "analyze_thread"
        handle_tool_analyze_thread(params, account)
      when "read_resources"
        handle_tool_read_resources(params, account)
      else
        Log.warn { "unknown tool: #{name}" }
        raise MCPError.new("Invalid tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
    end

    private def self.notification_status(notification) : JSON::Any
      owner = notification.owner
      object = notification.object

      reactions = [] of String

      liked = announced = false
      inclusion = [ActivityPub::Activity::Like, ActivityPub::Activity::Announce]
      activities = object.activities(inclusion: inclusion).select do |activity|
        if activity.actor == owner
          liked = true if activity.is_a?(ActivityPub::Activity::Like)
          announced = true if activity.is_a?(ActivityPub::Activity::Announce)
          break if liked && announced
        end
      end
      reactions << "liked" if liked
      reactions << "announced" if announced

      replies = object.replies(for_actor: owner).any? { |reply| reply.attributed_to == owner }
      reactions << "replied" if replies

      if reactions.empty?
        JSON::Any.new("new")
      else
        JSON::Any.new(reactions.map { |r| JSON::Any.new(r) })
      end
    end

    private def self.notification_to_json_any(notification) : JSON::Any?
      case notification
      in Relationship::Content::Notification::Mention
        JSON::Any.new({
          "type" => JSON::Any.new("mention"),
          "status" => notification_status(notification),
          "object_id" => JSON::Any.new(notification.object.id),
          "actor_id" => JSON::Any.new(notification.object.attributed_to.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Reply
        JSON::Any.new({
          "type" => JSON::Any.new("reply"),
          "status" => notification_status(notification),
          "object_id" => JSON::Any.new(notification.object.id),
          "actor_id" => JSON::Any.new(notification.object.attributed_to.id),
          "parent_id" => JSON::Any.new(notification.object.in_reply_to.not_nil!.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Follow
        response = notification.activity.as(ActivityPub::Activity::Follow).accepted_or_rejected?
        status = response ?
          "#{response.class.name.split("::").last.downcase}ed" :
          "new"
        JSON::Any.new({
          "type" => JSON::Any.new("follow"),
          "status" => JSON::Any.new(status),
          "follower_id" => JSON::Any.new(notification.activity.actor.id),
          "followee_id" => JSON::Any.new(notification.owner.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_actor_path(notification.activity.actor)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Like
        object = notification.activity.object
        likes = object.activities(inclusion: ActivityPub::Activity::Like)
        # five latest likes
        latest_likes = likes.reverse.first(5).map do |like|
          JSON::Any.new({
            "actor_id" => JSON::Any.new(like.actor.id),
            "handle" => JSON::Any.new(like.actor.handle),
            "liked_at" => JSON::Any.new(like.created_at.to_rfc3339),
          })
        end
        JSON::Any.new({
          "type" => JSON::Any.new("like"),
          "total_likes" => JSON::Any.new(likes.size),
          "latest_likes" => JSON::Any.new({
            "count" => JSON::Any.new(latest_likes.size),
            "actors" => JSON::Any.new(latest_likes)
          }),
          "object_id" => JSON::Any.new(object.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Dislike
        object = notification.activity.object
        dislikes = object.activities(inclusion: ActivityPub::Activity::Dislike)
        # five latest dislikes
        latest_dislikes = dislikes.reverse.first(5).map do |dislike|
          JSON::Any.new({
            "actor_id" => JSON::Any.new(dislike.actor.id),
            "handle" => JSON::Any.new(dislike.actor.handle),
            "disliked_at" => JSON::Any.new(dislike.created_at.to_rfc3339),
          })
        end
        JSON::Any.new({
          "type" => JSON::Any.new("dislike"),
          "total_dislikes" => JSON::Any.new(dislikes.size),
          "latest_dislikes" => JSON::Any.new({
            "count" => JSON::Any.new(latest_dislikes.size),
            "actors" => JSON::Any.new(latest_dislikes)
          }),
          "object_id" => JSON::Any.new(object.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Announce
        object = notification.activity.object
        announces = object.activities(inclusion: ActivityPub::Activity::Announce)
        # five latest announces
        latest_announces = announces.reverse.first(5).map do |announce|
          JSON::Any.new({
            "actor_id" => JSON::Any.new(announce.actor.id),
            "handle" => JSON::Any.new(announce.actor.handle),
            "announced_at" => JSON::Any.new(announce.created_at.to_rfc3339),
          })
        end
        JSON::Any.new({
          "type" => JSON::Any.new("announce"),
          "total_announces" => JSON::Any.new(announces.size),
          "latest_announces" => JSON::Any.new({
            "count" => JSON::Any.new(latest_announces.size),
            "actors" => JSON::Any.new(latest_announces)
          }),
          "object_id" => JSON::Any.new(object.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Follow::Hashtag
        JSON::Any.new({
          "type" => JSON::Any.new("follow_hashtag"),
          "hashtag" => JSON::Any.new(notification.name),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{hashtag_path(notification.name)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        }).tap do |json|
          if (latest_object = Tag::Hashtag.most_recent_object(notification.name))
            json.as_h["latest_object_id"] = JSON::Any.new(latest_object.id)
          end
        end
      in Relationship::Content::Notification::Follow::Mention
        JSON::Any.new({
          "type" => JSON::Any.new("follow_mention"),
          "mention" => JSON::Any.new(notification.name),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{mention_path(notification.name)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        }).tap do |json|
          if (latest_object = Tag::Mention.most_recent_object(notification.name))
            json.as_h["latest_object_id"] = JSON::Any.new(latest_object.id)
          end
        end
      in Relationship::Content::Notification::Follow::Thread
        JSON::Any.new({
          "type" => JSON::Any.new("follow_thread"),
          "thread" => JSON::Any.new(notification.object.thread),
          "latest_object_id" => JSON::Any.new(notification.object.id),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_thread_path(notification.object, anchor: false)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification::Poll::Expiry
        votes = notification.question.votes_by(notification.owner).map do |vote|
          JSON::Any.new(vote.id)
        end
        JSON::Any.new({
          "type" => JSON::Any.new("poll_expiry"),
          "question" => JSON::Any.new(notification.question.name),
          "votes" => JSON::Any.new(votes),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.question)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      in Relationship::Content::Notification
        nil
      end
    end
  end
end
