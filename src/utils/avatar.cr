require "../models/activity_pub/actor"

module Utils
  module Avatar
    ACTOR_COLOR_COUNT = 12

    def self.url_for(actor : ActivityPub::Actor?) : String
      if actor
        if actor.deleted?
          "/images/avatars/deleted.png"
        elsif actor.blocked?
          "/images/avatars/blocked.png"
        elsif !actor.down? && (icon = actor.icon.presence)
          icon
        elsif (actor_id = actor.id)
          "/images/avatars/color-#{actor_id % ACTOR_COLOR_COUNT}.png"
        else
          "/images/avatars/fallback.png"
        end
      else
        "/images/avatars/fallback.png"
      end
    end
  end
end
