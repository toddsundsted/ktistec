nav.ui.top.fixed.inverted.navigation.menu
  .ui.text.container
    - if (_account = env.account?)
      a.item href=actor_path(_account) Home
      a.item href=search_path Search
      a.item href=everything_path Everything
      .compact.menu
        .ui.simple.dropdown.item
          | Advanced
          i.dropdown.icon
          .menu
            a.item href=settings_path Settings
            a.item href=filters_path Filters
            a.item href=metrics_path Metrics
            a.item href=tasks_path Tasks
      .right.menu
        == form_tag(nil, sessions_path, method: "DELETE", class: "form") do
          .ui.action.input
            input.link.item type="submit" value="Sign Out"
    - elsif Account.count > 0
      a.item href=home_path Home
      .right.menu
        a.item href=sessions_path Sign In
    - else
      a.item Ktistec
