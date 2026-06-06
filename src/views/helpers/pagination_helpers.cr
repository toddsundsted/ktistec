module Ktistec::ViewHelper
  module ClassMethods
    # Returns the cursor value (`max` or `min`) from the query.
    #
    # Accepts both the underscore and hyphen spellings.
    #
    def cursor_param(query, name)
      query["#{name}_id"]? || query["#{name}-id"]?
    end

    # Returns true if the query carries any cursor pagination
    # parameters.
    #
    def cursor_paginated?(query)
      !!(cursor_param(query, "max") || cursor_param(query, "min"))
    end

    def cursor_pagination_params(env)
      max_limit = env.account? ? 1000 : 20
      query = env.params.query
      {
        max_id: cursor_param(query, "max").try(&.to_i64),
        min_id: cursor_param(query, "min").try(&.to_i64),
        limit:  Math.min(Math.max(query["limit"]?.try(&.to_i) || 10, 1), max_limit),
      }
    end

    def cursor_paginate_with_pins(actor, limit : Int32, &)
      tail = yield
      if tail.has_prev?
        {[] of ActivityPub::Object, tail}
      else
        pinned = actor.pinned_posts
        target = Math.max(limit - pinned.size, 1)
        if pinned.size > 0 && tail.size > target
          trimmed = Ktistec::Util::PaginatedArray(ActivityPub::Object).new(tail.to_a.first(target))
          trimmed.has_prev = tail.has_prev?
          trimmed.has_next = true
          trimmed.cursor_start = trimmed.first.id
          trimmed.cursor_end = trimmed.last.id
          {pinned, trimmed}
        else
          {pinned, tail}
        end
      end
    end

    def link_header(path, collection, limit)
      links = [] of String
      if collection.has_prev? && (cursor_start = collection.cursor_start)
        links << %Q(<#{Ktistec.host}#{path}?min_id=#{cursor_start}&limit=#{limit}>; rel="prev")
      end
      if collection.has_next? && (cursor_end = collection.cursor_end)
        links << %Q(<#{Ktistec.host}#{path}?max_id=#{cursor_end}&limit=#{limit}>; rel="next")
      end
      links.join(", ").presence
    end

    def paginate(env, collection, content_io)
      query = env.params.query # ameba:disable Lint/UselessAssign
      partial "partials/cursor_paginator"
    end
  end
end
