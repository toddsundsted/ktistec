require "../object"

class ActivityPub::Object
  class Tombstone < ActivityPub::Object
    @@external = false
  end
end
