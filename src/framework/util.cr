require "xml"

module Balloon
  module Util
    extend self

    def sanitize(content)
      return "" if content.nil? || content.empty?
      String.build do |build|
        sanitize(XML.parse_html(content,
          XML::HTMLParserOptions::RECOVER |
          XML::HTMLParserOptions::NODEFDTD |
          XML::HTMLParserOptions::NOIMPLIED |
          XML::HTMLParserOptions::NOERROR |
          XML::HTMLParserOptions::NOWARNING |
          XML::HTMLParserOptions::NONET
        ), build)
      end
    end

    private ELEMENTS = [
      "p",
      "h1", "h2", "h3", "h4", "h5", "h6",
      "ul", "ol", "li",
      "dl", "dt", "dd",
      "div", "span",
      "strong", "em",
      "blockquote",
      "pre",
      "img",
      "a"
    ]

    private ATTRIBUTES = {
      "a" => ["href"],
      "img" => ["src", "alt"]
    }

    private STRIP = [
      "head",
      "script",
      "style"
    ]

    private VOID = [
      "img"
    ]

    private def sanitize(html, build)
      name = html.name.downcase
      if html.element? && name.in?(STRIP)
        # skip
      elsif html.element? && name.in?(ELEMENTS)
        if (attributes = ATTRIBUTES[name]?)
          build << "<" << name
          (attributes & html.attributes.map(&.name)).each do |attr|
            build << " #{attr}='#{html[attr]}'"
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
        build << html.text
      end
    end

    def open(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
      was = url
      attempts.times do
        response = HTTP::Client.get(url, headers)
        case response.status_code
        when 200
          return yield response
        when 301, 302, 307, 308
          if (tmp = response.headers["Location"]?) && (url = tmp)
            next
          else
            break
          end
        else
          break
        end
      end
      message =
        if was != url
          "Open failed: #{was} [from #{url}]"
        else
          "Open failed: #{was}"
        end
      raise OpenError.new(message)
    end

    def open(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
      open(url, headers, attempts) do |response|
        response
      end
    end

    def open?(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
      yield open(url, headers, attempts)
    rescue OpenError
    end

    def open?(url, headers = HTTP::Headers{"Accept" => "application/activity+json"}, attempts = 10)
      open?(url, headers, attempts) do |response|
        response
      end
    end

    class OpenError < Exception
    end

    class PaginatedArray(T) < Array(T)
      def more=(more : Bool)
        @more = more
      end

      def more?
        @more
      end
    end
  end
end
