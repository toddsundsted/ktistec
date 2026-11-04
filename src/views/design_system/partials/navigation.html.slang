#navigation-components.design-system-section
  h2 Navigation Components
  .component-showcase
    h4 Top Navigation Menu
    .variation-group
      .variation-label Authenticated State
      nav.ui.top.inverted.navigation.menu
        .ui.text.container
          a.item href="#"
            i.home.icon
            span.text Home
          a.item href="#"
            i.search.icon
            span.text Search
          a.item href="#"
            i.globe.icon
            span.text Everything
          a.item href="#"
            i.cog.icon
            span.text Admin
          .right.menu
            .form
              input.link.item type="submit" value="Sign Out"
      .variation-label Unauthenticated State
      nav.ui.top.inverted.navigation.menu
        .ui.text.container
          a.item href="#"
            i.home.icon
            span.text Home
          .right.menu
            a.item Sign In
      .variation-label Site Setup State
      nav.ui.top.inverted.navigation.menu
        .ui.text.container
          a.item Ktistec
  .component-showcase
    h4 Footer
    nav.ui.bottom.inverted.menu
      .ui.text.container
        span.link.item
          a href="#" Powered by <em>Ktistec</em>
          | .
  .component-showcase
    h4 Secondary Menu
    .ui.text.container
      .ui.stackable.secondary.menu
        .menu-items style="display: flex"
          a.item Posts
          a.item Drafts
          a.item.notifications href="#" Notifications
            span.ui.mini.transitional.horizontal.circular.red.label 1
          a.item Followers
          a.item Following
  .component-showcase
    h4 Feed Controls
    .ui.text.container
      form.feed-controls.ui.secondary.pointing.menu
        .item
          .ui.mini.toggle.checkbox
            input#feed-controls-no-shares type="checkbox" name="filters" value="no-shares"
            label for="feed-controls-no-shares" Hide shares
        .item
          .ui.mini.toggle.checkbox
            input#feed-controls-no-replies type="checkbox" name="filters" value="no-replies" checked=true
            label for="feed-controls-no-replies" Hide replies
  .component-showcase
    h4 Pagination
    .ui.text.container
      nav.ui.secondary.pagination.menu
        a.item
          i.angle.double.left.icon
        a.item
          i.angle.double.right.icon
