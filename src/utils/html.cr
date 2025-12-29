require "json"
require "xml"
require "libxml_ext"
require "web_finger"

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
            if (attachment_data = figure["data-trix-attachment"]?)
              begin
                if (parsed = JSON.parse(attachment_data)) && parsed.as_h?
                  caption = parsed["alt"]?.try(&.as_s?)
                end
              rescue JSON::ParseException
                #
              end
            end
            enhancements.attachments << Attachment.new(image["src"], figure["data-trix-content-type"], caption)
            if caption.presence
              image["alt"] = caption
            end
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
            unless caption.content.presence
              caption.unlink
            end
          end
          figure.attributes.map(&.name).each do |attr|
            figure.delete(attr)
          end
        end

        xml.xpath_nodes("//a[contains(@href, '/remote/')]").each do |anchor|
          uri = URI.parse(anchor["href"])
          if uri.host
            server = URI.parse(Ktistec.host)
            unless uri.scheme == server.scheme && uri.host == server.host && uri.port == server.port
              next
            end
          end
          parts = uri.path.split('/')
          unless parts.size == 4
            next
          end
          id = parts[3].to_i64
          instance =
            case parts[2]
            when "actors" then ActivityPub::Actor.find?(id)
            when "objects" then ActivityPub::Object.find?(id)
            end
          if instance && instance.local?
            if uri.host
              anchor["href"] = instance.iri
            else
              anchor["href"] = URI.parse(instance.iri).path
            end
          end
        end

        xml.xpath_nodes("//node()[not(ancestor-or-self::a|ancestor-or-self::pre|ancestor-or-self::code)]/text()").each do |text|
          if (remainder = text.text).includes?('#') || remainder.includes?('＃') || remainder.includes?('@') || remainder.includes?("http://") || remainder.includes?("https://")
            cursor = insertion = XML.parse("<span/>").first_element_child.not_nil!
            text.replace_with(insertion)
            while !remainder.empty?
              text, tag, remainder = remainder.partition(%r{(https?://[^\s<>"#＃]+(?:[#＃][^\s<>"]*)?|\B[#＃]([[:alnum:]][[:alnum:]_-]+)|@[^@\s]+@[^@\s]+)\b})
              unless text.empty?
                cursor = cursor.add_sibling(XML::Node.new(text))
              end
              unless tag.empty?
                if tag.starts_with?("http://") || tag.starts_with?("https://")
                  url = tag.rstrip(".,!?);")
                  node = %Q|<a href="#{url}">#{url}</a>|
                  cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                elsif (hash_char = tag[0]) == '#' || hash_char == '＃'
                  hashtag = tag.lstrip('#').lstrip('＃')
                  node = %Q|<a href="#{Ktistec.host}/tags/#{hashtag}" class="hashtag" rel="tag">#{hash_char}#{hashtag}</a>|
                  cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                  enhancements.hashtags << Hashtag.new(name: hashtag, href: "#{Ktistec.host}/tags/#{hashtag}")
                else
                  mention = tag[1..]
                  if (actor = ActivityPub::Actor.match?(mention))
                    node = %Q|<a href="#{actor.iri}" class="mention" rel="tag">@#{actor.username}</a>|
                    cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                    enhancements.mentions << Mention.new(name: mention, href: actor.iri)
                  else
                    href =
                      begin
                        WebFinger.query("acct:#{mention.lchop('@')}").link("self").href.presence
                      rescue WebFinger::Error
                      end
                    if href
                      node = %Q|<a href="#{href}" class="mention" rel="tag">@#{mention}</a>|
                      cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                      enhancements.mentions << Mention.new(name: mention, href: href)
                    else
                      node = %Q|<span class="mention">@#{mention}</span>|
                      cursor = cursor.add_sibling(XML.parse(node).first_element_child.not_nil!)
                    end
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
