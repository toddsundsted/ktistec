require "json"
require "xml"
require "libxml_ext"

require "../models/activity_pub/actor"
require "../models/activity_pub/object"
require "../models/tag/hashtag"
require "../models/tag/mention"

module Ktistec
  module HTML
    extend self

    alias Attachment = ActivityPub::Object::Attachment
    alias Hashtag = Tag::Hashtag
    alias Mention = Tag::Mention

    class Enhancements
      property content : String = ""
      property attachments : Array(Attachment) = [] of Attachment
      property hashtags : Array(Hashtag) = [] of Hashtag
      property mentions : Array(Mention) = [] of Mention
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
        xml.xpath_nodes("//figure").each do |figure|
          figure.xpath_nodes(".//img").each do |image|
            enhancements.attachments << Attachment.new(image["src"], figure["data-trix-content-type"])
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

        xml.xpath_nodes("//node()[not(ancestor-or-self::a|ancestor-or-self::pre|ancestor-or-self::code)]/text()").each do |text|
          if (remainder = text.text).includes?('#') || remainder.includes?('@')
            cursor = insertion = XML.parse("<span/>").first_element_child.not_nil!
            text.replace_with(insertion)
            while !remainder.empty?
              text, tag, remainder = remainder.partition(%r{\B(#([[:alnum:]][[:alnum:]_-]+)|@[^@\s]+@[^@\s]+)\b})
              unless text.empty?
                cursor = cursor.add_sibling(XML::Node.new(text))
              end
              unless tag.empty?
                if tag[0] == '#'
                  hashtag = tag[1..]
                  node = %Q|<a href="#{Ktistec.host}/tags/#{hashtag}" class="hashtag" rel="tag">##{hashtag}</a>|
                  cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                  enhancements.hashtags << Hashtag.new(name: hashtag, href: "#{Ktistec.host}/tags/#{hashtag}")
                else
                  mention = tag[1..]
                  if (actor = ActivityPub::Actor.match?(mention))
                    node = %Q|<a href="#{actor.iri}" class="mention" rel="tag">@#{actor.username}</a>|
                    cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                    enhancements.mentions << Mention.new(name: mention, href: actor.iri)
                  else
                    node = %Q|<span class="mention">@#{mention}</span>|
                    cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                  end
                end
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
                if child.name == "br" && child.next.nil?
                  # SKIP
                elsif child.name == "br" && child.next.try(&.name) == "br"
                  # SKIP
                elsif child.name == "br" && child.previous.try(&.name) == "br"
                  build << "</p><p>"
                elsif child.name == "figure"
                  build << "</p>"
                  child.to_xml(build, options: XML::SaveOptions::AS_HTML)
                  build << "<p>"
                else
                  child.to_xml(build, options: XML::SaveOptions::AS_HTML)
                end
              end
              build << "</p>"
            else
              node.to_xml(build, options: XML::SaveOptions::AS_HTML)
            end
          end
        end.gsub(%r{<p><br></p>|<p></p>}, "")
      end
    end
  end
end
