require "json"
require "xml"
require "libxml_ext"

require "../models/activity_pub/actor"

module Ktistec
  module HTML
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
      property content : String = ""
      property attachments : Array(Attachment)?
      property hashtags : Array(String)?
      property mentions : Array(String)?
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

        enhancements.hashtags = hashtags = [] of String
        enhancements.mentions = mentions = [] of String

        xml.xpath_nodes("//node()[not(self::a)]/text()").each do |text|
          if (remainder = text.text).includes?('#')
            cursor = insertion = XML.parse("<span/>").first_element_child.not_nil!
            text.replace_with(insertion)
            while !remainder.empty?
              text, hashtag, remainder = remainder.partition(%r|\B#([[:alnum:]_-]+)\b|)
              unless text.empty?
                cursor = cursor.add_sibling(XML::Node.new(text))
              end
              unless hashtag.empty?
                hashtags << (hashtag = hashtag[1..])
                node = %Q|<a href="#{Ktistec.host}/tags/#{hashtag}" class="hashtag" rel="tag">##{hashtag}</a>|
                cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
              end
            end
            insertion.unlink
          elsif remainder.includes?('@')
            cursor = insertion = XML.parse("<span/>").first_element_child.not_nil!
            text.replace_with(insertion)
            while !remainder.empty?
              text, mention, remainder = remainder.partition(%r|\B@[^@\s]+@[^@\s]+\b|)
              unless text.empty?
                cursor = cursor.add_sibling(XML::Node.new(text))
              end
              unless mention.empty?
                mentions << (mention = mention[1..])
                node = (actor = ActivityPub::Actor.match?(mention)) ?
                  %Q|<a href="#{actor.iri}" class="mention" rel="tag">@#{actor.username}</a>| :
                  %Q|<span class="mention">@#{mention}</span>|
                cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
              end
            end
            insertion.unlink
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
  end
end
