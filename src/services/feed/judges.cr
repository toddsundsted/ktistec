require "./backend"
require "./backend/executable"
require "./judging"
require "./queue"

class Feed
  # Executable judges.
  #
  # A judge is an executable file in `directory`, named by its
  # filename.
  #
  module Judges
    extend self

    Log = ::Log.for(self)

    class_property directory : String = File.join("etc", "judges")

    NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/

    # Registered judges, by name and when last modified.
    #
    @@registered = {} of String => Time

    # Scans the directory, registering judges that appeared or
    # changed and unregistering judges that disappeared.
    #
    def scan : Nil
      found = discover
      (Backend.names - @@registered.keys).each do |name|
        if found.delete(name)
          Log.warn { "judge #{name} is not registered: a built-in backend has that name" }
        end
      end
      (@@registered.keys - found.keys).each do |name|
        Backend.unregister(name)
        @@registered.delete(name)
        Log.info { "judge #{name} is gone" }
      end
      found.each do |name, modified_at|
        next if @@registered[name]? == modified_at
        # an edit takes effect now, except a new revision or new params, which take effect only at startup
        previous = Backend.find?(name).as?(Backend::Executable) if @@registered[name]?
        Backend.register(name, Backend::Executable.new(File.join(directory, name), previous))
        @@registered[name] = modified_at
        # a changed judge resumes and gets a fresh start
        Queue.resume(name)
        Judging.forget(name)
        Log.info { "judge #{name} is registered" }
      end
    end

    # Returns the judges in the directory, and when each was modified.
    #
    private def discover : Hash(String, Time)
      found = {} of String => Time
      children =
        begin
          Dir.children(directory)
        rescue File::NotFoundError
          return found
        end
      children.each do |name|
        next unless NAME.matches?(name)
        if (info = judge?(File.join(directory, name)))
          found[name] = info.modification_time
        end
      end
      found
    end

    private def judge?(path : String) : File::Info?
      info = File.info(path)
      info if info.file? && info.permissions.owner_execute?
    rescue File::Error
    end
  end
end
