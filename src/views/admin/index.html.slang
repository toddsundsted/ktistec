.ui.text.container
  h1.ui.header Admin
  .ui.very.relaxed.list
    .item
      i.large.cog.icon
      .content
        a.header href=Ktistec::ViewHelper.settings_path Settings
        .description
          | Manage your account settings and site settings
    .item
      i.large.terminal.icon
      .content
        a.header href=Ktistec::ViewHelper.system_path Logging Levels
        .description
          | Configure logging levels for system components
    .item
      i.large.chart.line.icon
      .content
        a.header href=Ktistec::ViewHelper.metrics_path Metrics
        .description
          | View system metrics
    .item
      i.large.tasks.icon
      .content
        a.header href=Ktistec::ViewHelper.tasks_path Tasks
        .description
          | View scheduled tasks
    .item
      i.large.filter.icon
      .content
        a.header href=Ktistec::ViewHelper.filters_path Filters
        .description
          | Configure content filtering
    .item
      i.large.address.book.icon
      .content
        a.header href=Ktistec::ViewHelper.admin_accounts_path Accounts
        .description
          | Manage user accounts
    .item
      i.large.key.icon
      .content
        a.header href=Ktistec::ViewHelper.admin_oauth_clients_path OAuth Clients
        .description
          | Manage OAuth client applications
    .item
      i.large.lock.icon
      .content
        a.header href=Ktistec::ViewHelper.admin_oauth_tokens_path OAuth Tokens
        .description
          | View and manage OAuth access tokens
