require "./errors"
require "../utils/json_rpc"
require "../utils/paths"
require "../models/account"
require "../models/activity_pub/actor"
require "../models/activity_pub/object"

module MCP
  module Resources
    include Utils::Paths

    Log = ::Log.for("mcp")

    def self.handle_resources_list(request : JSON::RPC::Request) : JSON::Any
      resources = [] of JSON::Any

      resources << JSON::Any.new({
        "uri"      => JSON::Any.new(mcp_information_path),
        "mimeType" => JSON::Any.new("application/json"),
        "name"     => JSON::Any.new("Instance Information"),
      })

      Account.all.each do |account|
        resources << JSON::Any.new({
          "uri"      => JSON::Any.new(mcp_user_path(account)),
          "mimeType" => JSON::Any.new("application/json"),
          "name"     => JSON::Any.new(account.username),
        })
      end

      JSON::Any.new({
        "resources" => JSON::Any.new(resources),
      })
    end

    def self.handle_resources_templates_list(request : JSON::RPC::Request) : JSON::Any
      templates = [
        JSON::Any.new({
          "uriTemplate" => JSON::Any.new("ktistec://actors/{id*}"),
          "mimeType"    => JSON::Any.new("application/json"),
          "description" => JSON::Any.new(
            "Retrieve ActivityPub actor profiles including name, summary, icon, attachments, and URLs. Supports single ID " \
            "(ktistec://actors/123) or comma-separated IDs for batch retrieval (ktistec://actors/123,456,789)."
          ),
          "title" => JSON::Any.new("ActivityPub Actor"),
          "name"  => JSON::Any.new("Actor"),
        }),
        JSON::Any.new({
          "uriTemplate" => JSON::Any.new("ktistec://objects/{id*}"),
          "mimeType"    => JSON::Any.new("application/json"),
          "description" => JSON::Any.new(
            "Access ActivityPub posts/objects with name, summary, content, metadata, and relationships. Supports single ID " \
            "(ktistec://objects/123) or comma-separated IDs for batch retrieval (ktistec://objects/123,456,789)."
          ),
          "title" => JSON::Any.new("ActivityPub Object"),
          "name"  => JSON::Any.new("Object"),
        }),
      ]
      JSON::Any.new({
        "resourceTemplates" => JSON::Any.new(templates),
      })
    end

    def self.handle_resources_read(request : JSON::RPC::Request, account : Account) : JSON::Any
      unless (params = request.params)
        raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (uri = params["uri"]?.try(&.as_s))
        raise MCPError.new("Missing URI parameter", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "reading resource: user=#{mcp_user_path(account)} uri=#{uri}" }

      if uri =~ /^ktistec:\/\/users\/(\d+)$/
        unless (account_id = $1.to_i64?)
          raise MCPError.new("Invalid user ID in URI: #{$1}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end
        unless account.id == account_id
          raise MCPError.new("Access denied to user", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end
        unless account.reload!
          raise MCPError.new("User not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        actor = account.actor
        text_data = actor_contents(actor)

        # splice in the URI of the related actor resource
        text_data["actor_uri"] = JSON::Any.new(mcp_actor_path(account.actor))

        user_data = {
          "uri"      => JSON::Any.new(uri),
          "mimeType" => JSON::Any.new("application/json"),
          "name"     => JSON::Any.new(account.username),
          "text"     => JSON::Any.new(text_data.to_json),
        }

        JSON::Any.new({
          "contents" => JSON::Any.new([
            JSON::Any.new(user_data),
          ]),
        })
      elsif uri =~ /^ktistec:\/\/actors\/(\d+(,\d+)*)$/
        contents =
          $1.split(",").map(&.to_i64).map do |actor_id|
            unless (actor = ActivityPub::Actor.find?(actor_id))
              raise MCPError.new("Actor not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
            end

            text_data = actor_contents(actor)

            actor_data = {
              "uri"      => JSON::Any.new(mcp_actor_path(actor)),
              "mimeType" => JSON::Any.new("application/json"),
              "name"     => JSON::Any.new(actor.name || "Actor #{actor.id}"),
              "text"     => JSON::Any.new(text_data.to_json),
            }

            JSON::Any.new(actor_data)
          end

        JSON::Any.new({
          "contents" => JSON::Any.new(contents),
        })
      elsif uri =~ /^ktistec:\/\/objects\/(\d+(,\d+)*)$/
        contents =
          $1.split(",").map(&.to_i64).map do |object_id|
            unless (object = ActivityPub::Object.find?(object_id))
              raise MCPError.new("Object not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
            end

            text_data = object_contents(object)

            object_data = {
              "uri"      => JSON::Any.new(mcp_object_path(object)),
              "mimeType" => JSON::Any.new("application/json"),
              "name"     => JSON::Any.new(object.name || "Object #{object.id}"),
              "text"     => JSON::Any.new(text_data.to_json),
            }

            JSON::Any.new(object_data)
          end

        JSON::Any.new({
          "contents" => JSON::Any.new(contents),
        })
      elsif uri == mcp_information_path
        text_data = instance_information(account)

        information_data = {
          "uri"      => JSON::Any.new(uri),
          "mimeType" => JSON::Any.new("application/json"),
          "name"     => JSON::Any.new("Instance Information"),
          "text"     => JSON::Any.new(text_data.to_json),
        }

        JSON::Any.new({
          "contents" => JSON::Any.new([
            JSON::Any.new(information_data),
          ]),
        })
      else
        raise MCPError.new("Unsupported URI scheme: #{uri}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
    end

    def self.instance_information(account : Account) : Hash(String, JSON::Any)
      contents = Hash(String, JSON::Any).new

      # basic instance information
      contents["version"] = JSON::Any.new(Ktistec::VERSION)
      contents["host"] = JSON::Any.new(Ktistec.host)
      contents["site"] = JSON::Any.new(Ktistec.site)
      contents["description"] = JSON::Any.new("Ktistec ActivityPub Server Model Context Protocol (MCP) Interface")

      # authenticated user information
      contents["authenticated_user"] = JSON::Any.new({
        "uri"      => JSON::Any.new(mcp_user_path(account)),
        "username" => JSON::Any.new(account.username),
        "language" => JSON::Any.new(account.language || ""),
        "timezone" => JSON::Any.new(account.timezone),
      })

      # supported collections
      contents["collections"] = JSON::Any.new([
        JSON::Any.new("posts"),
        JSON::Any.new("drafts"),
        JSON::Any.new("timeline"),
        JSON::Any.new("notifications"),
        JSON::Any.new("likes"),
        JSON::Any.new("dislikes"),
        JSON::Any.new("announces"),
        JSON::Any.new("bookmarks"),
        JSON::Any.new("pins"),
        JSON::Any.new("followers"),
        JSON::Any.new("following"),
      ])

      # supported formatted collections
      contents["collection_formats"] = JSON::Any.new({
        "hashtag"  => JSON::Any.new(%q(hashtag#{name})),
        "mention"  => JSON::Any.new(%q(mention@{name})),
        "examples" => JSON::Any.new({
          "hashtag#krypton"  => JSON::Any.new("The collection of posts tagged with #krypton"),
          "mention@mxyzptlk" => JSON::Any.new("The collection of posts mentioning the user @mxyzptlk"),
        }),
      })

      # supported object types
      object_types = ActivityPub::Object.all_subtypes.map(&.split("::").last)
      contents["object_types"] = JSON::Any.new(object_types.map { |t| JSON::Any.new(t) })

      # supported actor types
      actor_types = ActivityPub::Actor.all_subtypes.map(&.split("::").last)
      contents["actor_types"] = JSON::Any.new(actor_types.map { |t| JSON::Any.new(t) })

      # statistics
      contents["statistics"] = JSON::Any.new({
        "total_users"   => JSON::Any.new(Account.all.size.to_i64),
        "total_actors"  => JSON::Any.new(ActivityPub::Actor.all.size.to_i64),
        "total_objects" => JSON::Any.new(ActivityPub::Object.all.size.to_i64),
      })

      contents
    end

    def self.actor_contents(actor : ActivityPub::Actor) : Hash(String, JSON::Any)
      contents = Hash(String, JSON::Any).new

      contents["uri"] = JSON::Any.new(mcp_actor_path(actor))
      contents["external_url"] = JSON::Any.new(actor.iri)
      contents["internal_url"] = JSON::Any.new("#{Ktistec.host}#{remote_actor_path(actor)}")
      if (name = actor.name)
        contents["name"] = JSON::Any.new(name)
      end
      if (summary = actor.summary)
        contents["summary"] = JSON::Any.new(summary)
      end
      if (icon = actor.icon)
        contents["icon"] = JSON::Any.new(icon)
      end
      if (image = actor.image)
        contents["image"] = JSON::Any.new(image)
      end
      if (attachments = actor.attachments.presence)
        contents["attachments"] = JSON::Any.new(attachments.map { |a| attachment_to_json_any(a) })
      end
      if (urls = actor.urls.presence)
        contents["urls"] = JSON::Any.new(urls.map { |u| JSON::Any.new(u) })
      end
      contents["type"] = JSON::Any.new(actor.class.to_s.split("::").last)

      contents
    end

    def self.object_contents(object : ActivityPub::Object) : Hash(String, JSON::Any)
      translation = object.translations.first?
      name = translation.try(&.name).presence || object.name.presence
      summary = translation.try(&.summary).presence || object.summary.presence
      content = translation.try(&.content).presence || object.content.presence

      if content && object.media_type == "text/markdown"
        content = Markd.to_html(content)
      end

      # process attachments to filter out embedded image URLs
      embedded_urls = [] of String
      if content && object.attachments
        begin
          html_doc = XML.parse_html(content)
          embedded_urls = html_doc.xpath_nodes("//img/@src").map(&.text)
        rescue
          # continue without filtering attachments
        end
      end
      filtered_attachments = object.attachments.try(&.reject(&.url.in?(embedded_urls)))

      contents = Hash(String, JSON::Any).new

      contents["uri"] = JSON::Any.new(mcp_object_path(object))
      contents["external_url"] = JSON::Any.new(object.iri)
      contents["internal_url"] = JSON::Any.new("#{Ktistec.host}#{remote_object_path(object)}")
      if name
        contents["name"] = JSON::Any.new(name)
      end
      if summary
        contents["summary"] = JSON::Any.new(summary)
      end
      if content
        contents["content"] = JSON::Any.new(content)
      end
      if object.media_type
        contents["media_type"] = JSON::Any.new(object.media_type)
      end
      if object.language
        contents["language"] = JSON::Any.new(object.language)
      end
      if (published = object.published)
        contents["published"] = JSON::Any.new(published.to_rfc3339)
      end
      if (attributed_to = object.attributed_to?)
        contents["attributed_to"] = JSON::Any.new(mcp_actor_path(attributed_to))
      end
      if (in_reply_to = object.in_reply_to?)
        contents["in_reply_to"] = JSON::Any.new(mcp_object_path(in_reply_to))
      end
      contents["type"] = JSON::Any.new(object.class.to_s.split("::").last)

      if filtered_attachments && !filtered_attachments.empty?
        attachment_data = filtered_attachments.map do |attachment|
          JSON::Any.new({
            "url"        => JSON::Any.new(attachment.url),
            "media_type" => JSON::Any.new(attachment.media_type),
            "caption"    => JSON::Any.new(attachment.caption || ""),
          })
        end
        contents["attachments"] = JSON::Any.new(attachment_data)
      end

      if translation
        contents["is_translated"] = JSON::Any.new(true)
        contents["original_language"] = JSON::Any.new(object.language || "")
      end

      activities = object.activities(inclusion: [ActivityPub::Activity::Like, ActivityPub::Activity::Dislike, ActivityPub::Activity::Announce])

      if !(likes = activities.select(ActivityPub::Activity::Like)).empty?
        actors_data = likes.reverse.map do |like|
          JSON::Any.new({
            "uri"      => JSON::Any.new(mcp_actor_path(like.actor)),
            "handle"   => JSON::Any.new(like.actor.handle),
            "liked_at" => JSON::Any.new(like.created_at.to_rfc3339),
          })
        end
        contents["likes"] = JSON::Any.new({
          "count"  => JSON::Any.new(likes.size),
          "actors" => JSON::Any.new(actors_data),
        })
      end

      if !(dislikes = activities.select(ActivityPub::Activity::Dislike)).empty?
        actors_data = dislikes.reverse.map do |dislike|
          JSON::Any.new({
            "uri"         => JSON::Any.new(mcp_actor_path(dislike.actor)),
            "handle"      => JSON::Any.new(dislike.actor.handle),
            "disliked_at" => JSON::Any.new(dislike.created_at.to_rfc3339),
          })
        end
        contents["dislikes"] = JSON::Any.new({
          "count"  => JSON::Any.new(dislikes.size),
          "actors" => JSON::Any.new(actors_data),
        })
      end

      if !(announces = activities.select(ActivityPub::Activity::Announce)).empty?
        actors_data = announces.reverse.map do |announce|
          JSON::Any.new({
            "uri"          => JSON::Any.new(mcp_actor_path(announce.actor)),
            "handle"       => JSON::Any.new(announce.actor.handle),
            "announced_at" => JSON::Any.new(announce.created_at.to_rfc3339),
          })
        end
        contents["announces"] = JSON::Any.new({
          "count"  => JSON::Any.new(announces.size),
          "actors" => JSON::Any.new(actors_data),
        })
      end

      if !(replies = object.replies(for_actor: nil)).empty? # `for_actor` is a dummy parameter
        objects_data = replies.map do |reply|
          reply_data = {
            "uri"    => JSON::Any.new(mcp_object_path(reply)),
            "author" => JSON::Any.new(mcp_actor_path(reply.attributed_to)),
          }
          if (published = reply.published)
            reply_data["published"] = JSON::Any.new(published.to_rfc3339)
          end
          if (content = reply.content.presence)
            preview = Ktistec::Util.render_as_text(content)
            if preview.size > 100
              preview = preview[0...100].rstrip + "..."
            end
            if (preview = preview.presence)
              reply_data["preview"] = JSON::Any.new(preview)
            end
          end
          JSON::Any.new(reply_data)
        end
        contents["replies"] = JSON::Any.new({
          "count"   => JSON::Any.new(replies.size.to_i64),
          "objects" => JSON::Any.new(objects_data),
        })
      end

      contents
    end

    private def self.attachment_to_json_any(attachment : ActivityPub::Actor::Attachment) : JSON::Any
      JSON::Any.new({
        "name"  => JSON::Any.new(attachment.name),
        "value" => JSON::Any.new(attachment.value),
      })
    end
  end
end
