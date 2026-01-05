.ui.text.admin.container
  h1.ui.header Admin
  .ui.very.relaxed.list role="list"
    .item.no-icon role="listitem"
      .content
        a.header href=Ktistec::ViewHelper.admin_accounts_path aria-label="Accounts - Manage user accounts" Accounts
        .description
          | Manage user accounts
    .item.no-icon role="listitem"
      .content
        a.header href=Ktistec::ViewHelper.filters_path aria-label="Filters - Configure content filtering" Filters
        .description
          | Configure content filtering
    .item.no-icon role="listitem"
      .content
        a.header href=Ktistec::ViewHelper.system_path aria-label="Logging Levels - Configure logging levels for system components" Logging Levels
        .description
          | Configure logging levels for system components
    .item role="listitem"
      i.large.chart.line.icon
      .content
        a.header href=Ktistec::ViewHelper.metrics_path aria-label="Metrics - View system metrics" Metrics
        .description
          | View system metrics
    .item.no-icon role="listitem"
      .content
        a.header href=Ktistec::ViewHelper.admin_oauth_clients_path aria-label="OAuth Clients - Manage OAuth client applications" OAuth Clients
        .description
          | Manage OAuth client applications
    .item.no-icon role="listitem"
      .content
        a.header href=Ktistec::ViewHelper.admin_oauth_tokens_path aria-label="OAuth Tokens - View and manage OAuth access tokens" OAuth Tokens
        .description
          | View and manage OAuth access tokens
    .item role="listitem"
      i.large.cog.icon
      .content
        a.header href=Ktistec::ViewHelper.settings_path aria-label="Settings - Manage your account settings and site settings" Settings
        .description
          | Manage your account settings and site settings
    .item role="listitem"
      i.large.tasks.icon
      .content
        a.header href=Ktistec::ViewHelper.tasks_path aria-label="Tasks - View scheduled tasks" Tasks
        .description
          | View scheduled tasks
  p.small.text Ktistec Version #{Ktistec::VERSION}
