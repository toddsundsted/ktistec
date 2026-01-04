module Ktistec
  # A pub/sub topic.
  #
  # ## Debouncing
  #
  # Topics support provider-side debouncing for high-frequency
  # subjects. When a subject is configured for debouncing,
  # notifications are batched and delivered after a fixed time window
  # instead of immediately.
  #
  # Configure debounce using a regex pattern matching subject names:
  #
  #     Ktistec::Topic.configure_debounce(/\/actors\/[^\/]+\/notifications$/, 1.second)
  #
  # Debounce configuration is in `src/controllers/streaming.cr`.
  #
  # Note: Subject names can change at runtime (see `.rename_subject`).
  # For example, thread subjects change from object IRI to thread IRI.
  # Design patterns to match *the category of possible names* for
  # a subject.
  #
  # Debounce behavior:
  # - First notification starts a timer
  # - Subsequent notifications during the window are queued
  # - When timer fires, queued values are delivered at once
  # - Subjects not matching any pattern are delivered immediately
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
    @@debounce_config = Hash(Regex, Time::Span).new
    @@pending_timers = Hash(String, Bool).new

    # Configures debounce for subjects matching `pattern`.
    #
    # `interval` is the debounce window.
    #
    def self.configure_debounce(pattern : Regex, interval : Time::Span)
      @@debounce_config[pattern] = interval
    end

    # Returns the debounce interval for a subject, or `nil`.
    #
    def self.debounce_interval_for(subject : String) : Time::Span?
      @@debounce_config.each do |pattern, interval|
        return interval if pattern.matches?(subject)
      end
    end

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
      @indexes.map { |i| @subjects[i] }.uniq!
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
      BUFFER_SIZE = 20

      property channel = Channel(Int32).new(BUFFER_SIZE)
      property queue = Array(String).new
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
    # Yields all queued values.
    #
    # Does not return unless the supplied block raises `Stop`, raises
    # an exception, or the channel is closed.
    #
    # A `timeout` may be specified to ensure the block is called
    # periodically.
    #
    def subscribe(timeout : Time::Span? = nil, &)
      @frozen = true
      Log.debug { %Q|[#{object_id}] subscribing to #{subjects.join(" ")}| }
      subscriptions = @indexes.reduce({} of Int32 => Subscription) do |acc, subject|
        subscription = Subscription.new
        @@subscriptions[subject] << subscription
        acc[subject] = subscription
        acc
      end
      begin
        loop do
          select_actions = subscriptions.values.map(&.channel.receive_select_action)
          select_actions += [timeout_select_action(timeout)] if timeout
          _, subject = Channel(Int32).select(select_actions)
          if subject
            if (subscription = subscriptions[subject]) && !subscription.queue.empty?
              values, subscription.queue = subscription.queue, Array(String).new
              Log.trace { %Q|[#{object_id}] yielding subject=#{@subjects[subject]} values=#{values}| }
              yield @subjects[subject], values
            else
              Log.error { %Q|[#{object_id}] nothing queued! skipping subject=#{@subjects[subject]}| }
            end
          else
            Log.trace { %Q|[#{object_id}] yielding on timeout| }
            yield nil, [] of String
          end
        end
      rescue Channel::ClosedError | Stop
        # exit
      ensure
        Log.trace { %Q|[#{object_id}] unsubscribing| }
        subscriptions.each do |subject, subscription|
          @@subscriptions[subject].delete(subscription)
          subscription.channel.close
        end
      end
    end

    # Notifies subscribers about updates.
    #
    # Passes an optional `value` to each subscriber.
    #
    # Does not block.
    #
    def notify_subscribers(value : String = "")
      @frozen = true
      Log.debug do
        subscriptions_count = @@subscriptions.values.sum(&.size)
        subjects = (0...@subjects.size).compact_map { |i| @subjects[i] }.join(" ")
        "statistics - subscriptions=#{subscriptions_count} slots=#{@subjects.size} free=#{@subjects.free} | #{subjects}"
      end
      Log.trace do
         "[#{object_id}] notifying subscribers subject=#{subjects.join(" ")} value=#{value}"
      end
      # look up the indexes that share the same name
      indexes =
        @indexes.flat_map do |index|
          name = @subjects[index]
          (0...@subjects.size).select { |i| @subjects[i] == name }
        end
      # notify them all
      indexes.each do |subject|
        if @@subscriptions.has_key?(subject)
          subject_name = @subjects[subject]
          debounce_interval = subject_name ? self.class.debounce_interval_for(subject_name) : nil
          @@subscriptions[subject].each do |subscription|
            unless subscription.channel.closed? || subscription.queue.includes?(value)
              subscription.queue << value
              if debounce_interval
                # start timer on first value. send when timer fires
                key = "#{subject}:#{subscription.object_id}"
                unless @@pending_timers[key]?
                  @@pending_timers[key] = true
                  spawn do
                    sleep debounce_interval
                    @@pending_timers.delete(key)
                    unless subscription.channel.closed?
                      begin
                        subscription.channel.send(subject)
                      rescue Channel::ClosedError
                        # channel has closed despite having been checked
                      end
                    end
                  end
                end
              else
                begin
                  subscription.channel.send(subject)
                rescue Channel::ClosedError
                  # channel has closed despite having been checked
                end
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
      @@debounce_config.clear
      @@pending_timers.clear
    end
  end
end
