require "markd"

require "../../../framework/model"

module Ktistec
  module Model
    module Renderable
      def to_html
        if (content = self.content)
          case self.media_type
          when "text/markdown"
            Markd.to_html content
          else
            content
          end
        end
      end
    end
  end
end
