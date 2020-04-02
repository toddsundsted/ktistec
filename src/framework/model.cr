module Balloon
  module Model
    # Marks properties as persistent.
    #
    annotation Persistent
    end

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

    @[Persistent]
    property id : Int64?
  end
end

require "../models/**"
