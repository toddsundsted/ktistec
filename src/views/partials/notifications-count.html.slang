.item.notifications
  a.ui href=actor_relationships_path(account.actor, "notifications") Notifications
  - if (count = account.actor.notifications(since: account.last_notifications_checked_at)) > 0
    .ui.mini.transitional.horizontal.circular.red.label= count
