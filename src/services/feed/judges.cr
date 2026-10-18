require "./backend"
require "./backend/executable"

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

    @@registered = Set(String).new

    # Scans the directory, registering judges that appeared and
    # unregistering judges that disappeared.
    #
    def scan : Nil
      found = discover
      (Backend.names - @@registered.to_a).each do |name|
        if found.delete(name)
          Log.warn { "judge #{name} is not registered: a built-in backend has that name" }
        end
      end
      (@@registered - found.keys).each do |name|
        Backend.unregister(name)
        @@registered.delete(name)
        Log.info { "judge #{name} is gone" }
      end
      found.each do |name, path|
        next if @@registered.includes?(name)
        Backend.register(name, Backend::Executable.new(path))
        @@registered << name
        Log.info { "judge #{name} is registered" }
      end
    end

    private def discover : Hash(String, String)
      found = {} of String => String
      children =
        begin
          Dir.children(directory)
        rescue File::NotFoundError
          return found
        end
      children.each do |name|
        next unless NAME.matches?(name)
        path = File.join(directory, name)
        found[name] = path if judge?(path)
      end
      found
    end

    private def judge?(path : String) : Bool
      info = File.info(path)
      info.file? && info.permissions.owner_execute?
    rescue File::Error
      false
    end
  end
end
