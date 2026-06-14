require "../../../framework/model"

module Ktistec
  module Model
    module Blockable
      @[Persistent]
      @[Insignificant]
      property blocked_at : Time?

      def block!
        self.before_block if self.responds_to?(:before_block)
        @blocked_at = Time.utc
        update_property(:blocked_at, @blocked_at) unless new_record?
        self.after_block if self.responds_to?(:after_block)
        self
      end

      def unblock!
        self.before_unblock if self.responds_to?(:before_unblock)
        @blocked_at = nil
        update_property(:blocked_at, @blocked_at) unless new_record?
        self.after_unblock if self.responds_to?(:after_unblock)
        self
      end

      def blocked?
        !!blocked_at
      end
    end
  end
end
