require "../../../src/services/feed/queue"

# Pauses a judge for each example in the enclosing group, and restores
# its prior pause, if any, after.
#
macro pause_judge(name, until time)
  around_each do |proc|
    %name = {{name}}
    %paused_until = Feed::Queue.paused_until(%name)
    Feed::Queue.pause(%name, until: {{time}})
    begin
      proc.call
    ensure
      if (%time = %paused_until)
        Feed::Queue.pause(%name, until: %time)
      else
        Feed::Queue.resume(%name)
      end
    end
  end
end
