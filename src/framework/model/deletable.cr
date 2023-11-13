require "../model"

module Ktistec
  module Model(*T)
    module Deletable
      @[Persistent]
      @[Insignificant]
      property deleted_at : Time?

      def delete
        self.before_delete if self.responds_to?(:before_delete)
        self.class.exec("UPDATE #{table_name} SET deleted_at = ? WHERE id = ?", @deleted_at = Time.utc, @id)
        self.after_delete if self.responds_to?(:after_delete)
        self
      end

      def deleted?
        !!deleted_at
      end
    end
  end
end

# :nodoc:
module Deletable
end
