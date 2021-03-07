h1 Search
p
  | Search the Fediverse for users by their username (“user@host.com”),
    or look up a user or a post by its URL.
form.ui.form class=(message ? "error" : "") method="GET"
  - if message
    .ui.error.message
      .header= message
  .field
    input type="text" name="query" value=query
  input.ui.primary.button type="submit" value="Search"
