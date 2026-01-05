h1 Search
p
  | Search by:
ul
  li Username (e.g., "alice") - searches cached users only, supports prefix matching
  li Full handle (e.g., "alice@host.com") - fetches remote users
  li URL - fetches remote users and posts
form.ui.form class=(message ? "error" : "") method="GET"
  - if message
    .ui.error.message
      .header= message
  .field
    input type="text" name="query" value=query
  input.ui.primary.button type="submit" value="Search"
br.transition.hidden
