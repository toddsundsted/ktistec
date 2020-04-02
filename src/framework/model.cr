module Balloon
  module Model
    # Model utilities.
    #
    module Utils
      # Returns the table name, given a model.
      #
      def self.table_name(clazz)
        (name = clazz.to_s.underscore) +
          if name.ends_with?(/s|ss|sh|ch|x|z/)
            "es"
          else
            "s"
          end
      end
    end
  end
end

require "../models/**"
