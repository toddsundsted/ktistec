require "ecr"
require "slang"
require "kemal"
require "markd"

require "../utils/emoji"
require "../utils/paths"

require "./helpers/html_helpers"
require "./helpers/json_helpers"
require "./helpers/miscellaneous_helpers"
require "./helpers/pagination_helpers"
require "./helpers/theming_helpers"

# Redefine the `render` macros provided by Kemal.

# Render a view with a layout as the superview.
#
macro render(content, layout)
  # Note: `__content_filename__` and `content_io` are magic variables
  # used by Kemal's implementation of "content_for" and must be in
  # scope for `yield_content` to work.

  __content_filename__ = {{ content }}

  content_io = IO::Memory.new
  Ktistec::ViewHelper.embed {{ content }}, content_io
  %content = content_io.to_s

  {% layout = "_layout_#{layout.gsub(%r[\/|\.], "_").id}" %}
  Ktistec::ViewHelper.{{ layout.id }}(
    env,
    yield_content("title"),
    yield_content("og_metadata"),
    yield_content("head"),
    %content
  )
end

# Render a view with the given filename.
#
macro render(content)
  String.build do |content_io|
    Ktistec::ViewHelper.embed {{ content }}, content_io
  end
end

module Ktistec::ViewHelper
  include Utils::Paths

  module ClassMethods
    # Renders an ActivityPub object.
    #
    # Parameters:
    # - `env`: HTTP request environment.
    # - `object`: The ActivityPub object to render.
    # - `actor`: The actor who performed the activity (defaults to object's `attributed_to`). May differ from author.
    # - `author`: The original author of the object (defaults to `actor`).
    # - `activity`: Optional activity containing this object (e.g., Like, Announce).
    # - `with_detail`: Renders expanded view with additional metadata.
    # - `as_context`: Indicates this object is being shown to provide context for (or is part of) the main content, not as the primary interactive element.
    # - `show_quote`: Whether or not to render quoted content (defaults to true).
    # - `for_thread`: Collection of objects in thread; enables thread view rendering.
    # - `for_actor`: Actor for whom view is being rendered.
    # - `highlight`: Whether or not to highlight this object in the feed.
    #
    def object_partial(env, object, actor = object.attributed_to(include_deleted: true), author = actor, *, activity = nil, with_detail = false, as_context = false, show_quote = true, for_thread = nil, for_actor = nil, highlight = false)
      if for_thread
        render "src/views/partials/thread.html.slang"
      elsif with_detail
        render "src/views/partials/detail.html.slang"
      else
        render "src/views/partials/object.html.slang"
      end
    end

    def body_partial(env, object, with_detail, is_deleted, show_quote, timezone)
      render "src/views/partials/object/content/body.html.slang"
    end

    def mention_page_mention_banner(env, mention, follow, count)
      render "src/views/partials/mention_page_mention_banner.html.slang"
    end

    def tag_page_tag_controls(env, hashtag, task, follow, count)
      render "src/views/partials/tag_page_tag_controls.html.slang"
    end

    def thread_page_thread_controls(env, thread, task, follow)
      render "src/views/partials/thread_page_thread_controls.html.slang"
    end
  end

  extend ClassMethods

  macro included
    extend ClassMethods
  end

  # Embed a view with the given filename.
  #
  macro embed(filename, io_name)
    {% ext = filename.split(".").last %}
    {% if ext == "ecr" %}
      ECR.embed {{ filename }}, {{ io_name }}
    {% elsif ext == "slang" %}
      Slang.embed {{ filename }}, {{ io_name }}
    {% else %}
      {% raise "unsupported template extension: #{ext.id}" %}
    {% end %}
  end

  # Parameter coercion

  macro id_param(env, type = :url, name = "id")
    begin
      env.params.{{ type.id }}[{{ name.id.stringify }}].to_i64
    rescue ArgumentError
      bad_request
    end
  end

  macro iri_param(env, path = nil, type = :url, name = "id")
    begin
      Base64.decode(%id = env.params.{{ type.id }}[{{ name.id.stringify }}])
      %path = {{ path }} || {{ env }}.request.path.split("/")[0..-2].join("/")
      "#{host}#{%path}/#{%id}"
    rescue Base64::Error
      bad_request
    end
  end

  # View helpers

  # The naming below matches the format of automatically generated
  # view helpers. View helpers for partials are *not* automatically
  # generated.

  def self._layout_src_views_layouts_default_html_ecr(env, title, og_metadata, head, content)
    render "src/views/layouts/default.html.ecr"
  end

  def self._view_src_views_partials_actor_panel_html_slang(env, actor)
    render "src/views/partials/actor-panel.html.slang"
  end

  def self._view_src_views_partials_collection_json_ecr(env, collection)
    render "src/views/partials/collection.json.ecr"
  end

  def self._view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor)
    render "src/views/partials/object/content.html.slang"
  end

  def self._view_src_views_partials_object_label_html_slang(env, author, actor)
    render "src/views/partials/object/label.html.slang"
  end

  def self._view_src_views_partials_object_content_quote_html_slang(env, object, quote, failed = false, error_message = nil, show_quote = true)
    render "src/views/partials/object/content/quote.html.slang"
  end

  def self._view_src_views_partials_object_content_poll_html_slang(env, poll, object_emojis, timezone)
    render "src/views/partials/object/content/poll.html.slang"
  end
end
