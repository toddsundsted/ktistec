require "../../../framework/model"

module Ktistec
  module Model(*T)
    module Blockable
      @[Persistent]
      @[Insignificant]
      property blocked_at : Time?

      def block
        self.class.exec("UPDATE #{table_name} SET blocked_at = ? WHERE id = ?", @blocked_at = Time.utc, @id)
        self
      end

      def unblock
        self.class.exec("UPDATE #{table_name} SET blocked_at = ? WHERE id = ?", @blocked_at = nil, @id)
        self
      end

      def blocked?
        !!blocked_at
      end
    end
  end
end

# :nodoc:
module Blockable
end
