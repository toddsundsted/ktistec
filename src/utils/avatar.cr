require "../framework/util"
require "../models/activity_pub/actor"
require "../safe/safe_uri"

module Utils
  module Avatar
    ACTOR_COLOR_COUNT = 12

    def self.url_for(actor : ActivityPub::Actor?) : Ktistec::SafeURI
      if actor
        if actor.deleted?
          Ktistec::SafeURI.assert_safe("/images/avatars/deleted.png")
        elsif actor.blocked?
          Ktistec::SafeURI.assert_safe("/images/avatars/blocked.png")
        elsif !actor.down? &&
              (icon = actor.icon.presence) &&
              (uri = Ktistec::SafeURI.from?(icon)) &&
              Ktistec::Util.url_scheme(icon).in?(Ktistec::Util::SAFE_IRI_SCHEMES)
          uri
        elsif (actor_id = actor.id)
          Ktistec::SafeURI.assert_safe("/images/avatars/color-#{actor_id % ACTOR_COLOR_COUNT}.png")
        else
          Ktistec::SafeURI.assert_safe("/images/avatars/fallback.png")
        end
      else
        Ktistec::SafeURI.assert_safe("/images/avatars/fallback.png")
      end
    end
  end
end
