require "html"
require "uri"
require "xml"

module Ktistec::RSS
  # Generates an RSS feed from an array of objects.
  #
  def self.generate_rss_feed(objects, feed_title, feed_url, description, language = nil)
    String.build do |rss|
      rss << %{<?xml version="1.0" encoding="UTF-8"?>\n}
      rss << %{<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n}
      rss << %{<channel>\n}
      rss << %{<title><![CDATA[#{feed_title}]]></title>\n}
      rss << %{<description><![CDATA[#{description}]]></description>\n}
      rss << %{<generator>Ktistec</generator>\n}
      rss << %{<language>#{language}</language>\n} if language
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
              XML::HTMLParserOptions::NONET
            ).xpath_string("string()")
            stripped.size > 50 ? "#{stripped[0...50]}…" : stripped
          else
            "Post by #{author.name}"
          end
        description = object.content || "Post by #{author.name}"
        published_date = object.published || object.created_at
        rss << %{<item>\n}
        rss << %{<title><![CDATA[#{title}]]></title>\n}
        rss << %{<description><![CDATA[#{description}]]></description>\n}
        rss << %{<link>#{::HTML.escape(object.display_link)}</link>\n}
        rss << %{<guid isPermaLink="true">#{::HTML.escape(object.display_link)}</guid>\n}
        rss << %{<pubDate>#{published_date.to_rfc2822}</pubDate>\n}
        if (username = author.username)
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
