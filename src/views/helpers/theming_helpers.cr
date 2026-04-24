require "html"
require "uri"

require "../../utils/avatar"

module Ktistec::ViewHelper
  module ClassMethods
    def actor_states(object, author, actor, followed_actors)
      states = [] of String
      if followed_actors
        states << "author-followed-by-me" if author && followed_actors.includes?(author.iri)
        states << "actor-followed-by-me" if actor && actor != author && followed_actors.includes?(actor.iri)
      end
      states
    end

    def object_states(object)
      states = [] of String
      states << "is-sensitive" if object.sensitive
      states << "is-draft" if object.draft?
      states << "is-deleted" if object.deleted?
      states << "is-blocked" if object.blocked?
      states << "has-replies" if object.replies_count > 0
      states << "has-quote" if object.quote_iri
      states << "has-media" if object.attachments.try { |a| a.size > 0 }
      if (attributed_to = object.attributed_to?)
        states << "visibility-#{visibility(attributed_to, object)}"
      end
      states
    end

    def mention_states(object, actor)
      states = [] of String
      object_mentions = object.mentions
      is_mentioned = object_mentions.any? { |m| m.href == actor.iri }
      if is_mentioned
        states << (object_mentions.size == 1 ? "mentions-only-me" : "mentions-me")
      end
      states
    end

    def quote_states(object, actor)
      states = [] of String
      if object.quote?.try(&.attributed_to?) == actor
        states << "quotes-me"
      end
      states
    end

    def object_data_attributes(object, author, actor, followed_hashtags, followed_mentions)
      attrs = {} of String => String
      if (id = object.id)
        attrs["data-object-id"] = id.to_s
      end
      if author
        attrs["data-author-handle"] = author.handle
        attrs["data-author-iri"] = author.iri
      end
      if actor && actor != author
        attrs["data-actor-handle"] = actor.handle
        attrs["data-actor-iri"] = actor.iri
      end
      object_hashtags = object.hashtags.map(&.name.downcase)
      if object_hashtags.presence
        attrs["data-hashtags"] = object_hashtags.first(10).join(" ")
      end
      if followed_hashtags
        matched = object_hashtags.select { |hashtag| followed_hashtags.includes?(hashtag) }
        if matched.presence
          attrs["data-followed-hashtags"] = matched.join(" ")
        end
      end
      object_mentions = object.mentions.map(&.name.downcase)
      if object_mentions.presence
        attrs["data-mentions"] = object_mentions.first(10).join(" ")
      end
      if followed_mentions
        matched = object_mentions.select { |mention| followed_mentions.includes?(mention) }
        if matched.presence
          attrs["data-followed-mentions"] = matched.join(" ")
        end
      end
      attrs
    end

    def depth(object)
      object ? "depth-#{Math.min(object.depth, 9)}" : ""
    end

    def activity_type_class(activity)
      activity ? "activity-#{activity.type.split("::").last.downcase}" : ""
    end

    def actor_type_class(actor)
      actor ? "actor-#{actor.type.split("::").last.downcase}" : ""
    end

    def object_type_class(object)
      object ? "object-#{object.type.split("::").last.downcase}" : ""
    end

    def actor_icon(actor, classes = nil, *, include_actor_id = true)
      src = Utils::Avatar.url_for(actor)
      if actor
        if actor.deleted?
          alt = "Deleted user"
        elsif actor.blocked?
          alt = "Blocked user"
        elsif actor.id
          alt = actor.display_name
        else
          alt = "User"
        end
      else
        alt = "User"
      end
      begin
        uri = URI.parse(src)
        unless uri.scheme.nil? || uri.scheme.in?(%w[http https])
          src = "/images/avatars/fallback.png"
        end
      rescue URI::Error
        src = "/images/avatars/fallback.png"
      end
      attrs = [
        %Q(src="#{::HTML.escape(src)}"),
        %Q(alt="#{::HTML.escape(alt)}"),
        %Q(loading="lazy"),
      ]
      attrs.push %Q(data-actor-id="#{actor.id}") if actor && actor.id && include_actor_id
      attrs.unshift %Q(class="#{::HTML.escape(classes)}") if classes
      %Q(<img #{attrs.join(" ")}>)
    end

    def actor_type(actor)
      icon =
        if actor
          case actor.type.split("::").last
          when "Person"
            "user"
          when "Group"
            "users"
          when "Organization"
            "university"
          when "Service"
            "plug"
          when "Application"
            "laptop"
          else
            "user"
          end
        else
          "user"
        end
      %Q(<i class="actor-type-overlay #{icon} icon"></i>)
    end
  end
end
