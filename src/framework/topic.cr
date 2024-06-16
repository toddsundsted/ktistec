module Ktistec
  # A pub/sub topic.
  #
  class Topic
    Log = ::Log.for(self)

    @frozen = false

    @subjects = [] of String

    # Returns the subjects.
    #
    def subjects
      @subjects.dup
    end

    # Adds a subject.
    #
    # Raises an exception if the topic is frozen.
    #
    def <<(subject : String)
      raise Error.new("cannot add subject to topic if frozen") if @frozen
      @subjects << subject
    end

    private class Subscription
      property channel = Channel(String).new

      property? latched = false

      def unlatch!
        @latched = false
      end

      def latch!
        @latched = true
      end
    end

    @@subscriptions = Hash(String, Array(Subscription)).new do |h, k|
      h[k] = Array(Subscription).new
    end

    # Clears all subscriptions.
    #
    # This is useful when setting up tests. It shouldn't be used in
    # production.
    #
    def self.clear_subscriptions!
      @@subscriptions.clear
    end

    # Returns the subscriptions to this topic.
    #
    def subscriptions
      @@subscriptions.select { |k, _| k.in?(@subjects) }.reject { |_, v| v.empty? }
    end

    # A topic error.
    #
    class Error < Exception
    end

    # Cleanly stops a subscription when raised.
    #
    class Stop < Exception
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
      subscriptions = @subjects.reduce({} of String => Subscription) do |subscriptions, subject|
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
              Log.debug { %Q|[#{object_id}] yielding subject "#{subject}"| }
              yield subject
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
        "statistics - subscriptions: #{subscriptions_count}"
      end
      @subjects.each do |subject|
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
  end
end
