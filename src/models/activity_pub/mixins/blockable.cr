require "../../../framework/model"

module Ktistec
  module Model
    module Blockable
      @[Persistent]
      @[Insignificant]
      property blocked_at : Time?

      def block!
        @blocked_at = Time.utc
        update_property(:blocked_at, @blocked_at) unless new_record?
        self
      end

      def unblock!
        @blocked_at = nil
        update_property(:blocked_at, @blocked_at) unless new_record?
        self
      end

      def blocked?
        !!blocked_at
      end
    end
  end
end
