require "ecr"
require "kemal"
require "markd"

require "../slang"
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
  # scope for `yield_content` to work. `content_io` must be a plain
  # local (assignable), not a `String.build` block parameter — Kemal's
  # `yield_content` macro reassigns it to capture nested output.

  __content_filename__ = {{content}}

  content_io = IO::Memory.new
  Ktistec::ViewHelper.embed {{content}}, content_io
  %content = content_io.to_s

  {% layout = "_layout_#{layout.gsub(%r[\/|\.], "_").id}" %}
  Ktistec::ViewHelper.{{layout.id}}(
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
    Ktistec::ViewHelper.embed {{content}}, content_io
  end
end

# Renders a Slang partial into the surrounding `content_io` scope.
#
# Two forms:
#
#     - partial "partials/visibility_controls"
#     - partial paginate(env, objects)
#
# String-literal form: resolves `path` against `src/views/` (unless
# already prefixed with `src/`) and appends `.html.slang` if no such
# extension is present.
#
# Method-call form: appends `content_io: content_io` as a named
# argument.
#
macro partial(arg)
  {% if arg.is_a?(StringLiteral) %}
    {% base = arg.starts_with?("src/") ? arg : "src/views/#{arg.id}" %}
    {% resolved = base.ends_with?(".html.slang") ? base : "#{base.id}.html.slang" %}
    ::Slang.embed({{resolved}}, content_io)
  {% elsif arg.is_a?(Call) %}
    {% rcv = arg.receiver %}
    {% if !rcv.is_a?(Nop) %}{{rcv}}.{% end %}{{arg.name.id}}(
      {% for a in arg.args %}{{a}}, {% end %}
      {% if arg.named_args %}{% for n in arg.named_args %}{{n.name.id}}: {{n.value}}, {% end %}{% end %}
      content_io: content_io,
    )
  {% else %}
    {% raise "expected a string-literal path or method call" %}
  {% end %}
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
    # - `themed`: Whether or not to emit custom-theme metadata (feed rendering only; ignored when `for_thread`/`with_detail` is set).
    #
    def object_partial(env, object, actor = object.attributed_to(include_deleted: true), author = actor, *, activity = nil, with_detail = false, as_context = false, show_quote = true, for_thread = nil, for_actor = nil, highlight = false, themed = true, content_io)
      partial "partials/object/wrapper"
    end

    def object_content_partial(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor, content_io)
      partial "partials/object/content"
    end

    def body_partial(env, object, with_detail, show_quote, timezone, content_io)
      partial "partials/object/content/body"
    end

    def mention_page_mention_banner(env, mention, follow, count, content_io)
      partial "partials/mention_page_mention_banner"
    end

    def tag_page_tag_controls(env, hashtag, task, follow, count, content_io)
      partial "partials/tag_page_tag_controls"
    end

    def thread_page_thread_controls(env, thread, task, follow, content_io)
      partial "partials/thread_page_thread_controls"
    end

    def actor_panel_partial(env, actor, content_io)
      partial "partials/actor-panel"
    end

    def collection_json_partial(env, collection)
      render "src/views/partials/collection.json.ecr"
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
      ECR.embed {{filename}}, {{io_name}}
    {% elsif ext == "slang" %}
      Slang.embed {{filename}}, {{io_name}}
    {% else %}
      {% raise "unsupported template extension: #{ext.id}" %}
    {% end %}
  end

  # Parameter coercion

  macro id_param(env, type = :url, name = "id")
    begin
      env.params.{{type.id}}[{{name.id.stringify}}].to_i64
    rescue ArgumentError
      bad_request
    end
  end

  macro iri_param(env, path = nil, type = :url, name = "id")
    begin
      Base64.decode(%id = env.params.{{type.id}}[{{name.id.stringify}}])
      %path = {{path}} || {{env}}.request.path.split("/")[0..-2].join("/")
      "#{host}#{%path}/#{%id}"
    rescue Base64::Error
      bad_request
    end
  end

  # View helpers

  # The name below matches the format of automatically generated
  # layout helpers. It is consumed by the `render(content, layout)`
  # macro at the top of this file and by `framework/controller.cr`'s
  # response macros, both of which derive the helper name from the
  # layout path.

  def self._layout_src_views_layouts_default_html_ecr(env, title, og_metadata, head, content)
    render "src/views/layouts/default.html.ecr"
  end
end
