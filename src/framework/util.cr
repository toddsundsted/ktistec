require "json"
require "xml"
require "libxml_ext"

module Ktistec
  module Util
    extend self

    struct Attachment
      include JSON::Serializable

      property url : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      def initialize(@url, @media_type)
      end

      def image?
        media_type.in?(%w[image/bmp image/gif image/jpeg image/png image/svg+xml image/x-icon image/apng image/webp])
      end

      def video?
        media_type.in?(%w[video/mp4 video/webm video/ogg])
      end

      def audio?
        media_type.in?(%w[audio/mp4 audio/webm audio/ogg audio/flac])
      end
    end

    class Enhancements
      property attachments : Array(Attachment)?
      property content : String = ""
    end

    # Improves the content we generate ourselves.
    #
    def enhance(content)
      return Enhancements.new if content.nil? || content.empty?
      xml = XML.parse_html("<div>#{content}</div>",
        XML::HTMLParserOptions::RECOVER |
        XML::HTMLParserOptions::NODEFDTD |
        XML::HTMLParserOptions::NOIMPLIED |
        XML::HTMLParserOptions::NOERROR |
        XML::HTMLParserOptions::NOWARNING |
        XML::HTMLParserOptions::NONET
      )
      Enhancements.new.tap do |enhancements|
        enhancements.attachments = ([] of Attachment).tap do |attachments|
          xml.xpath_nodes("//figure").each do |figure|
            figure.xpath_nodes(".//img").each do |image|
              attachments << Attachment.new(image["src"], figure["data-trix-content-type"])
            end
            figure.xpath_nodes(".//a[.//img]").each do |anchor|
              children = anchor.children
              anchor.unlink
              children.each do |child|
                figure.add_child(child)
              end
            end
            figure.xpath_nodes(".//figcaption").each do |caption|
              caption.attributes.map(&.name).each do |attr|
                caption.delete(attr)
              end
            end
            figure.attributes.map(&.name).each do |attr|
              figure.delete(attr)
            end
          end
        end
        enhancements.content = String.build do |build|
          xml.xpath_nodes("/*/node()").each do |node|
            if node.name == "div"
              build << "<p>"
              node.children.each do |child|
                if child.name == "br" && child.next.try(&.name) == "br"
                  # SKIP
                elsif child.name == "br" && child.previous.try(&.name) == "br"
                  build << "</p><p>"
                elsif child.name == "figure"
                  build << "</p>"
                  build << child.to_xml(options: XML::SaveOptions::AS_HTML)
                  build << "<p>"
                else
                  build << child.to_xml(options: XML::SaveOptions::AS_HTML)
                end
              end
              build << "</p>"
            else
              build << node.to_xml(options: XML::SaveOptions::AS_HTML)
            end
          end
        end.gsub(/^<p><\/p>|<p><\/p>$/, "")
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
      "strong", "em",
      "blockquote",
      "pre",
      "img",
      "a",
      "br"
    ]

    private ATTRIBUTES = {
      "a" => ["href"],
      "img" => ["src", "alt"]
    }

    private VALUES = {
      "a" => {"rel", "ugc"},
      "img" => {"class", "ui image"}
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
          (attributes & html.attributes.map(&.name)).each do |attr|
            build << " #{attr}='#{html[attr]}'"
          end
          if (values = VALUES[name]?)
            build << " #{values[0]}='#{values[1]}'"
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

    class PaginatedArray(T) < Array(T)
      property? more : Bool = false
    end
  end
end
