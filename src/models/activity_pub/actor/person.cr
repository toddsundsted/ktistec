require "../actor"

class ActivityPub::Actor
  class Person < ActivityPub::Actor
    ALLOWED_TYPE_MIGRATIONS = [
      "ActivityPub::Actor::Application",
      "ActivityPub::Actor::Group",
      "ActivityPub::Actor::Organization",
      "ActivityPub::Actor::Service",
    ]
  end
end
