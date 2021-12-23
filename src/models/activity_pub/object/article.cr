require "../object"

class ActivityPub::Object
  class Article < ActivityPub::Object
    @@external = false
  end
end
