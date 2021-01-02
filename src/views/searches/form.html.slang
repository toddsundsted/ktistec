h1 Search
form.ui.form class=(message ? "error" : "") method="GET"
  - if message
    .ui.error.message
      .header= message
  .field
    input type="text" name="query" value=query
  input.ui.primary.button type="submit" value="Search"
