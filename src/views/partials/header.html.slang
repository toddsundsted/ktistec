nav.ui.top.fixed.inverted.navigation.menu
  .ui.text.container
    - if (_account = env.account?)
      a.item href=actor_path(_account)
        i.home.icon
        span.text Home
      a.item href=search_path
        i.search.icon
        span.text Search
      a.item href=everything_path
        i.globe.icon
        span.text Everything
      a.item href=admin_path
        i.cog.icon
        span.text Admin
      .right.menu
        == form_tag(nil, sessions_path, method: "DELETE", class: "form") do
          .ui.input
            input.link.item type="submit" value="Sign Out"
    - elsif Account.count > 0
      a.item href=home_path
        i.home.icon
        span.text Home
      .right.menu
        a.item href=sessions_path Sign In
    - else
      a.item Ktistec
