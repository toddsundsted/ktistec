module Ktistec
  # A pub/sub topic.
  #
  class Topic
    Log = ::Log.for(self)

    @frozen = false

    # A topic error.
    #
    class Error < Exception
    end

    # Cleanly stops a subscription when raised.
    #
    class Stop < Exception
    end

    # Manages the mapping of subjects to indexes.
    #
    # The string representation of subjects are mutable. Topics refer
    # to subjects by their index rather than their string representation
    # so that subscriptions are not affected when that changes.
    #
    class Subjects
      @subjects = Array(String).new
      @counts = Array(Int32).new

      def size
        @subjects.size
      end

      def free
        @counts.count(&.zero?)
      end

      def [](i : Int) : String?
        @counts[i] > 0 ? @subjects[i] : nil
      end

      def map(t : String) : Int
        if (i = @subjects.index(t)) && @counts[i] > 0
          @counts[i] += 1
          i
        elsif (i = @counts.index(0))
          @subjects[i] = t
          @counts[i] = 1
          i
        else
          @subjects << t
          @counts << 1
          @subjects.size - 1
        end
      end

      def unmap(i : Int)
        @counts[i] > 0 ? (@counts[i] -= 1) : @counts[i]
      end

      def clear(i : Int)
        @counts[i] = 0
      end
    end

    @@subjects = Subjects.new

    # All subjects.
    #
    @subjects : Subjects

    # The indexes of the topic's subjects.
    #
    @indexes : Array(Int32)

    def initialize
      @subjects = @@subjects
      @indexes = Array(Int32).new
    end

    # Removes subjects that no longer belong to any topic.
    #
    # Note: this method should only be called during garbage
    # collection.
    #
    def finalize
      @indexes.each { |i| @subjects.unmap(i) }
    end

    # Returns the subjects.
    #
    def subjects
      @indexes.map { |i| @subjects[i] }.uniq
    end

    # Adds a subject.
    #
    # Raises an exception if the topic is frozen.
    #
    def <<(subject : String)
      raise Error.new("cannot add subject to topic if frozen") if @frozen
      @indexes << @subjects.map(subject)
    end

    # A subscription.
    #
    private class Subscription
      property channel = Channel(Int32).new
      property? latched = false

      def unlatch!
        @latched = false
      end

      def latch!
        @latched = true
      end
    end

    @@subscriptions = Hash(Int32, Array(Subscription)).new do |h, k|
      h[k] = Array(Subscription).new
    end

    # Returns the subscriptions to this topic.
    #
    def subscriptions
      @@subscriptions.select { |k, v| k.in?(@indexes) && v.presence }.transform_keys { |k| @subjects[k] }
    end

    # Subscribes to updates about the topic.
    #
    # Does not return unless the supplied block raises `Stop`, raises
    # an exception, or the channel is closed.
    #
    # A `timeout` may be specified to ensure the block is called
    # periodically.
    #
    def subscribe(timeout : Time::Span? = nil, &block)
      @frozen = true
      subscriptions = @indexes.reduce({} of Int32 => Subscription) do |subscriptions, subject|
        subscription = Subscription.new
        @@subscriptions[subject] << subscription
        subscriptions[subject] = subscription
        subscriptions
      end
      begin
        loop do
          select_actions = subscriptions.values.map(&.channel.receive_select_action)
          select_actions += [timeout_select_action(timeout)] if timeout
          i, subject = Channel(String).select(select_actions)
          if subject
            if (subscription = subscriptions[subject]).latched?
              Log.debug { %Q|[#{object_id}] yielding subject "#{@subjects[subject]}"| }
              yield @subjects[subject]
              subscription.unlatch!
            end
          else
            Log.debug { %Q|[#{object_id}] yielding on timeout| }
            yield nil
          end
        end
      rescue Channel::ClosedError | Stop
        # exit
      ensure
        subscriptions.each do |subject, subscription|
          @@subscriptions[subject].delete(subscription)
          subscription.channel.close
        end
      end
    end

    # Notifies subscribers about updates.
    #
    # Does not block.
    #
    def notify_subscribers
      @frozen = true
      Log.debug do
        subscriptions_count = @@subscriptions.values.map(&.size).sum
        "statistics - subscriptions=#{subscriptions_count} | space - subjects=#{@subjects.size} free=#{@subjects.free}"
      end
      # look up the indexes that share the same name
      indexes =
        @indexes.map do |index|
          name = @subjects[index]
          (0...@subjects.size).select { |i| @subjects[i] == name }
        end.flatten
      # notify them all
      indexes.each do |subject|
        if @@subscriptions.has_key?(subject)
          @@subscriptions[subject].each do |subscription|
            unless subscription.latched?
              subscription.latch!
              unless subscription.channel.closed?
                subscription.channel.send(subject)
              end
            end
          end
        end
      end
    end

    # Renames a subject across all topics.
    #
    def self.rename_subject(before, after)
      if before && after && before != after
        @@subjects.@subjects.each_with_index do |subject, i|
          if subject == before
            @@subjects.@subjects[i] = after
          end
        end
      end
    end

    # Resets the topic class state.
    #
    # Clears all subscriptions. Clears all subjects.
    #
    # This is useful when testing. It should not be used in any other
    # context!
    #
    def self.reset!
      @@subscriptions.clear
      @@subjects = Subjects.new
    end
  end
end
