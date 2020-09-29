require "../model"

module Ktistec
  module Model
    module Deletable
      @[Persistent]
      @[Insignificant]
      property deleted_at : Time?

      def delete
        Ktistec.database.exec("UPDATE #{table_name} SET deleted_at = ? WHERE id = ?", @deleted_at = Time.utc, @id)
        @id = nil
        self
      end

      def deleted?
        deleted_at
      end
    end
  end
end

# :nodoc:
module Deletable
end
