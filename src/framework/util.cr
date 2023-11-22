require "uri"
require "xml"

module Ktistec
  module Util
    extend self

    # Generates a random, URL-safe identifier.
    #
    # 64 bits should ensure it takes about 5 billion attempts to
    # generate a collision.
    #
    def id
      Random::Secure.urlsafe_base64(8)
    end

    # Renders content as simple text.
    #
    def render_as_text(content)
      return "" if content.nil? || content.empty?
      String.build do |build|
        render_as_text(XML.parse_html("<div>#{content}</div>",
          XML::HTMLParserOptions::RECOVER |
          XML::HTMLParserOptions::NODEFDTD |
          XML::HTMLParserOptions::NOIMPLIED |
          XML::HTMLParserOptions::NOERROR |
          XML::HTMLParserOptions::NOWARNING |
          XML::HTMLParserOptions::NONET
        ), build)
      end.chomp
    end

    # not strictly block elements (`br` is inline), these are elements
    # that should be replaced with a newline.

    private BLOCK = [
      "p",
      "h1", "h2", "h3", "h4", "h5", "h6",
      "ul", "ol", "li",
      "dl", "dt", "dd",
      "div", "figure",
      "blockquote",
      "pre",
      "br"
    ]

    private def render_as_text(html, build)
      name = html.name.downcase
      if html.element? && name.in?(BLOCK)
        html.children.each { |child| render_as_text(child, build) }
        build << "\n"
      elsif html.element? || html.document?
        html.children.each { |child| render_as_text(child, build) }
      elsif html.text?
        html.to_s(build)
      end
    end

    # Cleans up the content we receive from others.
    #
    def sanitize(content)
      return "" if content.nil? || content.empty?
      String.build do |build|
        sanitize(XML.parse_html("<div>#{content}</div>",
          XML::HTMLParserOptions::RECOVER |
          XML::HTMLParserOptions::NODEFDTD |
          XML::HTMLParserOptions::NOIMPLIED |
          XML::HTMLParserOptions::NOERROR |
          XML::HTMLParserOptions::NOWARNING |
          XML::HTMLParserOptions::NONET
        ), build)
      end.gsub(/^<div>|<\/div>$/, "")
    end

    private ELEMENTS = [
      "p",
      "h1", "h2", "h3", "h4", "h5", "h6",
      "ul", "ol", "li",
      "dl", "dt", "dd",
      "div", "span", "figure", "figcaption",
      "strong", "em", "sup", "sub",
      "blockquote",
      "code", "pre",
      "img",
      "a",
      "br"
    ]

    private ATTRIBUTES = {
      a: {
        keep: ["href"],
        remote: [{"target", "_blank"}, {"rel", "ugc"}],
        local: [{"data-turbo-frame", "_top"}],
        key: "href"
      },
      img: {
        keep: ["src", "alt"],
        all: [{"class", "ui image"}, {"loading", "lazy"}]
      },
      span: {
        class: ["invisible", "ellipsis"]
      }
    }

    private STRIP = [
      "head",
      "script",
      "style"
    ]

    private VOID = [
      "img",
      "br"
    ]

    private def sanitize(html, build)
      name = html.name.downcase
      if html.element? && name.in?(STRIP)
        # skip
      elsif html.element? && name.in?(ELEMENTS)
        if (attributes = ATTRIBUTES[name]?)
          build << "<" << name
          if (keep = attributes[:keep]?)
            (keep & html.attributes.map(&.name)).each do |attribute|
              build << " #{attribute}='#{html[attribute]}'"
            end
          end
          if (classes = attributes[:class]?) && (class_attribute = html.attributes["class"]?)
            classes = (classes & class_attribute.content.split).join(' ')
            build << " class='#{classes}'" if classes.presence
          end
          local =
            if (key = attributes[:key]?) && (value = html.attributes[key]?)
              uri = URI.parse(value.text)
              (!uri.scheme && !uri.host) || Ktistec.host == "#{uri.scheme}://#{uri.host}"
            end
          if (local && (values = attributes[:local]?)) ||
             (!local && (values = attributes[:remote]?)) ||
             (values = attributes[:all]?)
            build << values.map { |value| " #{value[0]}='#{value[1]}'" }.join
          end
          build << ">"
        else
          build << "<" << name << ">"
        end
        html.children.each { |child| sanitize(child, build) }
        unless name.in?(VOID)
          build << "</" << name << ">"
        end
      elsif html.element? || html.document?
        empty = html.element? && build.empty?
        build << "<p>" if empty
        html.children.each { |child| sanitize(child, build) }
        build << "</p>" if empty
      elsif html.text?
        html.to_s(build)
      end
    end

    # Converts the array of words to comma-separated sentence form
    # where the last word is joined by a connector word (by default
    # "and").
    #
    def to_sentence(array, *, words_connector = ", ", last_word_connector = " and ")
      case array.size
      when 0
        ""
      when 1
        array[0].to_s
      when 2
        "#{array[0]}#{last_word_connector}#{array[1]}"
      else
        "#{array[0...-1].join(words_connector)}#{last_word_connector}#{array[-1]}"
      end
    end

    # Pluralizes a singular noun.
    #
    def pluralize(noun)
      if noun.ends_with?(/s|ss|sh|ch|x|z/)
        "#{noun}es"
      elsif noun.ends_with?(/[^aeiou]y/)
        "#{noun.chomp('y')}ies"
      else
        "#{noun}s"
      end
    end

    class PaginatedArray(T)
      def initialize
        @array = Array(T).new
      end

      def initialize(size : Int)
        @array = Array(T).new(size)
      end

      delegate :<<, :each, :each_with_index, :empty?, :first, :pop, :size, :to_a, :to_s, :inspect, :includes?, to: @array

      def map(&block : T -> U) : PaginatedArray(U) forall U
        PaginatedArray(U).new(size).tap do |array|
          each { |t| array << yield t }
          array.more = more?
        end
      end

      property? more : Bool = false
    end
  end
end
