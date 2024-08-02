# Publish updates about models to subscribers.
#
class ModelChannel(M)
  Log = ::Log.for(self)

  private class Subscription
    property channel = Channel(Int64).new

    property? latched = false

    def unlatch!
      @latched = false
    end

    def latch!
      @latched = true
    end
  end

  @subscriptions = Hash(Int64, Array(Subscription)).new do |h, k|
    h[k] = Array(Subscription).new
  end

  class Stop < Exception
  end

  # Returns the subscriptions.
  #
  def subscriptions
    @subscriptions.reject { |_, v| v.empty? }.transform_keys { |k| M.find(k) }
  end

  # Subscribes to updates about `model`.
  #
  # Does not return unless the block raises `Stop`, raises an
  # exception, or the channel is closed.
  #
  # A `timeout` may be specified to ensure the block is called
  # periodically.
  #
  def subscribe(model : M, timeout : Time::Span? = nil, &block)
    id = model.id.not_nil!
    subscription = Subscription.new
    @subscriptions[id] << subscription
    begin
      loop do
        select
        # if `timeout` is `nil`, time out after some long period of
        # time (e.g. a hour) but don't yield. there's no obvious way
        # to conditionally include the timeout branch.
        when timeout(timeout || 1.hour)
          if timeout
            yield nil
          end
        when id = subscription.channel.receive
          if subscription.latched?
            yield M.find(id)
            subscription.unlatch!
          end
        end
      end
    rescue Channel::ClosedError | Stop
      # do nothing
    ensure
      @subscriptions[id].delete(subscription)
      subscription.channel.close
    end
  end

  # Publishes an update about `model`.
  #
  # Does not block.
  #
  def publish(model : M)
    id = model.id.not_nil!
    if @subscriptions.has_key?(id)
      @subscriptions[id].each do |subscription|
        unless subscription.latched?
          subscription.latch!
          unless subscription.channel.closed?
            subscription.channel.send(id)
          end
        end
      end
    end
  end
end
