require "html"

require "../safe"

# Runtime helpers used by codegen-emitted templates.
#
# The codegen emits direct `<<` writes for the literal-and-static
# common case. These helpers handle the dynamic cases where a runtime
# value must be inspected before being emitted (presence-checked,
# bool-aware attribute rendering, splat iteration).
#
module Slang::Runtime
  extend self

  # HTML attribute names whose values are URLs.
  #
  URL_ATTRIBUTE_NAMES = %w[
    href src action formaction data cite poster manifest
    xlink:href background longdesc usemap
  ]

  # Matches event-handler attribute names (`onclick`, `onmouseover`, ...).
  #
  EVENT_HANDLER_RE = /\Aon[a-z]+\z/i

  # Matches attribute names accepted via splat.
  #
  ATTRIBUTE_NAME_RE = /\A[a-zA-Z_][a-zA-Z0-9_-]*\z/

  # Emits a value to the buffer in HTML data context.
  #
  # `Ktistec::SafeHTML` is emitted raw; `Ktistec::SafeJSON` is emitted
  # raw; any other value has `.to_s` applied and is HTML-escaped.
  #
  def emit(io : IO, value : ::Ktistec::SafeHTML) : Nil
    io << value.to_s
  end

  # :ditto:
  def emit(io : IO, value : ::Ktistec::SafeJSON) : Nil
    io << value.to_s
  end

  # :ditto:
  def emit(io : IO, value) : Nil
    ::HTML.escape(value.to_s, io)
  end

  # Emits a value to the buffer in HTML comment context.
  #
  # HTML-escapes (covers `& < > " '`) and breaks any `--` run with a
  # numeric character reference, preventing early-close of the
  # surrounding `<!-- ... -->`. No type dispatch: `Ktistec::SafeHTML`
  # is *not* admitted raw, because its safety claim is HTML-data
  # context, not comment context (markup containing `--` would break
  # out).
  #
  def emit_comment(io : IO, value) : Nil
    io << ::HTML.escape(value.to_s).gsub("--", "-&#45;")
  end

  # Emits a single attribute for an unwrapped `name=expr` source
  # form.
  #
  # - `Ktistec::SafeAttrValue` -> emit ` name="<value.to_s>"` raw
  # - `true`                   -> emit ` name`
  # - `false`                  -> omit entirely
  # - else                     -> emit ` name="<HTML-escaped value.to_s>"`
  #
  # `Ktistec::SafeHTML` is intentionally *not* admitted raw here:
  # markup like `<em>x</em>` is safe in HTML data slots but would
  # render as visible text inside an attribute (the type lattice
  # treats the two destinations as distinct). It falls through to
  # the HTML-escape branch below.
  #
  def emit_attr(io : IO, name : String, value : ::Ktistec::SafeAttrValue) : Nil
    io << ' ' << name << "=\"" << value.to_s << '"'
  end

  # :ditto:
  def emit_attr(io : IO, name : String, value) : Nil
    case value
    when true
      io << ' ' << name
    when false
      # omit
    else
      io << ' ' << name << "=\""
      ::HTML.escape(value.to_s, io)
      io << '"'
    end
  end

  # event-handler attributes (`onclick=`, `onmouseover=`, ...) admit
  # no runtime value type. `Slang::Runtime.emit_event_attr` is
  # intentionally undefined — any expression-form event-handler
  # attribute (`onclick=expr`) routes to this method name during
  # codegen and fails to compile with "undefined method
  # `emit_event_attr`". author-typed string literals like
  # `onclick="alert(1)"` are unaffected.

  # Emits a single URL attribute (`href`, `src`, ...).
  #
  # Only `Ktistec::SafeURI?` is admitted. Plain `String` (or any other
  # type) at a URL-attribute callsite fails to compile. `nil` is
  # silently skipped.
  #
  def emit_url_attr(io : IO, name : String, value : ::Ktistec::SafeURI?) : Nil
    return if value.nil?
    io << ' ' << name << "=\""
    ::HTML.escape(value.to_s, io)
    io << '"'
  end

  # Emits a merged `class="..."` attribute combining a literal prefix
  # and any number of dynamic class sources.
  #
  def emit_class(io : IO, literal_prefix : String, *dynamics : String?) : Nil
    has_literal = !literal_prefix.empty?
    has_dynamic = dynamics.any? &.try(&.presence)
    return if !has_literal && !has_dynamic

    io << " class=\""
    first = true
    if has_literal
      io << literal_prefix
      first = false
    end
    dynamics.each do |d|
      if (value = d.try(&.presence))
        io << ' ' unless first
        first = false
        ::HTML.escape(value, io)
      end
    end
    io << '"'
  end

  # Iterates a splat hash, emitting each key/value pair as an
  # attribute. `nil` values are skipped.
  #
  # When `skip_class` is true, the `class` key is suppressed -- the
  # caller has already routed its value through `emit_class`.
  #
  def emit_splat_attrs(io : IO, hash, skip_class : Bool) : Nil
    hash.each do |key, value|
      next if value.nil?
      key_s = key.to_s
      next if skip_class && key_s == "class"
      unless key_s.matches?(ATTRIBUTE_NAME_RE)
        raise ArgumentError.new("invalid splat attribute name `#{key_s}`")
      end
      if key_s.matches?(EVENT_HANDLER_RE)
        raise ArgumentError.new("event-handler attribute `#{key_s}` cannot be set via splat")
      end
      if URL_ATTRIBUTE_NAMES.includes?(key_s.downcase)
        unless value.is_a?(::Ktistec::SafeURI)
          raise ArgumentError.new("URL attribute `#{key_s}` requires SafeURI in splat, got #{value.class}")
        end
        emit_url_attr(io, key_s, value)
      else
        emit_attr(io, key_s, value)
      end
    end
  end
end
