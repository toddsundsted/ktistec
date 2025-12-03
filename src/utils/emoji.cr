require "../models/tag/emoji"

module Ktistec
  module Emoji
    extend self

    # Replaces :shortcode: tokens with <img> tags.
    #
    # Only replaces emoji in text content, not inside HTML
    # elements/attributes.
    #
    def emojify(content : String?, emoji_tags : Enumerable(Tag::Emoji)) : String
      return "" if content.nil? || content.blank?
      return content if emoji_tags.empty?

      content.split(/(<[^>]+>)/).map do |part|
        if part.starts_with?('<') && part.ends_with?('>')
          part
        else
          result = part
          emoji_tags.each do |emoji|
            shortcode_pattern = ":#{emoji.name}:"
            img_tag = %(<img src="#{emoji.href.not_nil!}" class="emoji" alt="#{shortcode_pattern}" title="#{shortcode_pattern}">)
            result = result.gsub(shortcode_pattern, img_tag)
          end
          result
        end
      end.join
    end
  end
end
