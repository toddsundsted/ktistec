require "../model"

module Ktistec
  module Model(*T)
    module Deletable
      @[Persistent]
      @[Insignificant]
      property deleted_at : Time?

      def delete!
        self.before_delete if self.responds_to?(:before_delete)
        @deleted_at = Time.utc
        update_property(:deleted_at, @deleted_at) unless new_record?
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
