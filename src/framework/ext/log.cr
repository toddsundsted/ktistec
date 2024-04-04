require "log"

class Log
  class Builder
    # Returns all log sources.
    #
    # See: Log.for(source, ...)
    #
    def sources
      @mutex.synchronize do
        @logs.keys.select(&.presence).dup
      end
    end
  end

  # Sets up logging from the supplied hash of sources and severities.
  #
  # Unless specified, sources are set to the default severity (as
  # indicated by the environment variable "LOG_LEVEL", or
  # `Log::Severity::Info` if "LOG_LEVEL" is not set).
  #
  def self.setup(bindings : Hash(String, Severity))
    setup do |c|
      backend = IOBackend.new
      c.bind "*", default, backend
      builder.sources.each do |source|
        if (severity = bindings[source]?)
          c.bind source, severity, backend
        end
      end
    end
  end

  # Returns the default severity.
  #
  def self.default
    Log::Severity.parse(ENV.fetch("LOG_LEVEL", "INFO"))
  end
end
