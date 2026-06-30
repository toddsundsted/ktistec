require "json"

require "../models/activity_pub/object"
require "../models/activity_pub/activity/announce"

module API
  # Encodes and decodes API status ids.
  #
  # A status id is normally an `ActivityPub::Object` id. A reblog
  # wrapper, however, needs its own id distinct from the reblogged
  # object's id, so it encodes the `ActivityPub::Activity::Announce`
  # id with a reserved high bit set. The bit disambiguates the two
  # otherwise-overlapping namespaces while keeping the id a positive,
  # all-digit string.
  #
  struct StatusID
    # The reserved high bit marking an announce-derived (reblog) id.
    #
    REBLOG_FLAG = 1_i64 << 62

    private def initialize(@value : String)
    end

    # Encodes the id of an object.
    #
    def self.from_object(object : ActivityPub::Object) : StatusID
      new(object.id!.to_s)
    end

    # Encodes the id of an announce (reblog) as a wrapper id distinct
    # from the reblogged object's id.
    #
    def self.from_announce(announce : ActivityPub::Activity::Announce) : StatusID
      new((REBLOG_FLAG | announce.id!).to_s)
    end

    # Decodes a wire id into its kind and internal id.
    #
    # Returns `{:announce, id}` for a reblog wrapper id, `{:object, id}`
    # for a plain object id, or `nil` if the input is malformed or out
    # of range.
    #
    def self.decode(string : String) : {Symbol, Int64}?
      value = string.to_i64?
      return unless value && value > 0
      if (value & REBLOG_FLAG) != 0
        id = value & ~REBLOG_FLAG
        {:announce, id} if id > 0
      else
        {:object, value}
      end
    end

    delegate :to_s, :to_json, to: @value

    def ==(other : StatusID) : Bool
      @value == other.@value
    end

    def ==(other : String) : Bool
      @value == other
    end
  end
end
