module Ktistec::ViewHelper
  module ClassMethods
    # NOTE: This method is redefined when running tests. It sets the
    # `max_size` to 20, regardless of account authentication.

    def pagination_params(env)
      max_size = env.account? ? 1000 : 20
      {
        page: Math.max(env.params.query["page"]?.try(&.to_i) || 1, 1),
        size: Math.min(env.params.query["size"]?.try(&.to_i) || 10, max_size),
      }
    end

    def cursor_pagination_params(env)
      max_limit = env.account? ? 1000 : 20
      {
        max_id: env.params.query["max_id"]?.try(&.to_i64),
        min_id: env.params.query["min_id"]?.try(&.to_i64),
        limit:  Math.min(Math.max(env.params.query["limit"]?.try(&.to_i) || 10, 1), max_limit),
      }
    end

    def link_header(path, collection, limit)
      links = [] of String
      if (cursor_start = collection.cursor_start)
        links << %Q(<#{Ktistec.host}#{path}?min_id=#{cursor_start}&limit=#{limit}>; rel="prev")
      end
      if collection.more? && (cursor_end = collection.cursor_end)
        links << %Q(<#{Ktistec.host}#{path}?max_id=#{cursor_end}&limit=#{limit}>; rel="next")
      end
      links.join(", ").presence
    end

    def paginate(env, collection)
      query = env.params.query
      if collection.cursor_start
        render "src/views/partials/cursor_paginator.html.slang"
      else
        page = (p = query["page"]?) && (p = p.to_i) > 0 ? p : 1 # ameba:disable Lint/UselessAssign
        render "src/views/partials/paginator.html.slang"
      end
    end
  end
end
