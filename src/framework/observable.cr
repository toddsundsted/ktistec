module Ktistec
  module Observable
    # Holds observer callbacks for a class's lifecycle events and
    # dispatches them to the affected instance.
    #
    class Registry(T)
      def initialize
        @observers = Hash(Symbol, Array(T -> Nil)).new
      end

      # Registers an observer for `event`.
      #
      # The block receives the affected instance.
      #
      def observe(event : Symbol, &block : T ->) : Nil
        (@observers[event] ||= [] of T -> Nil) << block
        nil
      end

      # Invokes the observers registered for `event`, in registration
      # order, passing `instance`.
      #
      def notify(event : Symbol, instance : T) : Nil
        @observers[event]?.try &.each(&.call(instance))
        nil
      end

      # Removes all registered observers.
      #
      # For test isolation.
      #
      def clear : Nil
        @observers.clear
      end
    end
  end
end
