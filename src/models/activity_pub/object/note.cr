require "../object"

class ActivityPub::Object
  class Note < ActivityPub::Object
    @@external = false
  end
end
