require "log"

class Log::Builder
  def sources
    @mutex.synchronize do
      @logs.keys.select(&.presence).dup
    end
  end
end
