require "../../models/activity_pub/object"

module ObjectBuilder
  # Result of building an ActivityPub object.
  #
  # Contains the built object and validation errors.
  #
  class BuildResult
    property object : ActivityPub::Object
    property errors : Hash(String, Array(String))

    def initialize(@object, @errors = Hash(String, Array(String)).new)
    end

    # Returns `true` if there are no validation errors.
    #
    def valid?
      @errors.empty?
    end

    # Adds a validation error for a field.
    #
    def add_error(field : String, message : String)
      @errors[field] ||= [] of String
      @errors[field] << message
    end
  end
end
