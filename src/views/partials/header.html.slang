nav.ui.top.fixed.inverted.navigation.menu
  .ui.text.container
    - if (_account = env.account?)
      a.item href=actor_path(_account) Home
      a.item href=search_path Search
      a.item href=settings_path Settings
      .right.menu
        form method="POST" action=sessions_path
          input type="hidden" name="_method" value="delete"
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          .ui.action.input
            input.link.item type="submit" value="Sign Out"
    - elsif Account.count > 0
      a.item href=sessions_path Sign In
    - else
      a.item Ktistec
