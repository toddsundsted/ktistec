#refresh-posts-message.ui.info.icon.message
  i.sync.icon
  .content
    .header There are new posts!
    p: a href=Ktistec::SafeURI.from(path) data-turbo-prefetch="false" data-turbo-action="replace" Refresh
