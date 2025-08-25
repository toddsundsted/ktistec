require "../framework/util"
require "../utils/html"

module Ktistec
  module DescriptionEnhancer
    extend self

    @@description : String? = nil
    @@nonce : Int64? = nil

    def enhanced_description
      nonce = Settings.nonce
      description = Ktistec.settings.description.presence

      return nil unless description

      if @@nonce != nonce
        enhancements = HTML.enhance(description)
        @@description = Ktistec::Util.sanitize(enhancements.content)
        @@nonce = nonce
      end

      @@description
    end

    def clear_cache!
      @@description = nil
      @@nonce = nil
    end
  end
end
