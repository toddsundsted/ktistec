require "../model"

module Ktistec
  module Model(*T)
    module Undoable
      @[Persistent]
      @[Insignificant]
      property undone_at : Time?

      def undo
        self.before_undo if self.responds_to?(:before_undo)
        self.class.exec("UPDATE #{table_name} SET undone_at = ? WHERE id = ?", @undone_at = Time.utc, @id)
        self.after_undo if self.responds_to?(:after_undo)
        self
      end

      def undone?
        !!undone_at
      end
    end
  end
end

# :nodoc:
module Undoable
end
