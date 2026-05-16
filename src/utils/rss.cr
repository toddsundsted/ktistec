require "html"
require "uri"
require "xml"

require "../framework/util"

module Ktistec::RSS
  # Generates an RSS feed from an array of objects.
  #
  def self.generate_rss_feed(objects, feed_title, feed_url, description, language = nil)
    String.build do |rss|
      rss << %{<?xml version="1.0" encoding="UTF-8"?>\n}
      rss << %{<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n}
      rss << %{<channel>\n}
      rss << %{<title>#{::HTML.escape(feed_title)}</title>\n}
      rss << %{<description>#{::HTML.escape(description)}</description>\n}
      rss << %{<generator>Ktistec</generator>\n}
      rss << %{<language>#{::HTML.escape(language)}</language>\n} if language
      rss << %{<link>#{::HTML.escape(feed_url)}</link>\n}
      rss << %{<atom:link href="#{::HTML.escape(feed_url)}/feed.rss" rel="self" type="application/rss+xml" />\n}
      rss << %{<lastBuildDate>#{Time.utc.to_rfc2822}</lastBuildDate>\n}
      objects.each do |object|
        author = object.attributed_to
        title =
          if (raw_title = object.name.presence || object.content.presence)
            stripped = XML.parse_html(
              raw_title,
              XML::HTMLParserOptions::RECOVER |
              XML::HTMLParserOptions::NODEFDTD |
              XML::HTMLParserOptions::NOIMPLIED |
              XML::HTMLParserOptions::NOERROR |
              XML::HTMLParserOptions::NOWARNING |
              XML::HTMLParserOptions::NONET,
            ).xpath_string("string()")
            stripped.size > 50 ? "#{stripped[0...50]}…" : stripped
          else
            Ktistec::Util.render_as_text("Post by #{author.name}").strip
          end
        description =
          if (raw_content = object.content.presence)
            Ktistec::Util.sanitize(raw_content).to_s
          else
            Ktistec::Util.render_as_text("Post by #{author.name}").strip
          end
        published_date = object.published || object.created_at
        next unless (item_url = object.display_link.try(&.to_s))
        rss << %{<item>\n}
        rss << %{<title>#{::HTML.escape(title)}</title>\n}
        rss << %{<description>#{::HTML.escape(description)}</description>\n}
        rss << %{<link>#{::HTML.escape(item_url)}</link>\n}
        rss << %{<guid isPermaLink="true">#{::HTML.escape(item_url)}</guid>\n}
        rss << %{<pubDate>#{published_date.to_rfc2822}</pubDate>\n}
        if (username = author.username)
          username = Ktistec::Util.render_as_text(username).strip
          host = URI.parse(feed_url).host.not_nil!
          rss << %{<author>#{::HTML.escape(username)}@#{::HTML.escape(host)}</author>\n}
        end
        rss << %{</item>\n}
      end
      rss << %{</channel>\n}
      rss << %{</rss>}
    end
  end
end
