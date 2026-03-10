- content_for "title" do
  | Filters
h1 Content Filter Terms
turbo-frame#terms
  - if terms.empty?
    p
      | This section lists content filter terms. No terms have been
        defined.
  - else
    section.terms
      table.ui.very.basic.table
        tr
          th.four.wide Term
          th.one.wide
        - terms.each do |term|
          tr.term id="term-#{term.id}"
            td == wrap_filter_term term.term
            td == form_button(filter_path(term), method: "DELETE", button_class: "ui dangerous mini iconic button") do
              i.x.icon
              | Delete
  p
    | Content filters prevent matching posts from being added to your
      inbox. Filters only apply to posts that arrive <em>after</em> the
      filter is created—they do not retroactively filter posts already
      in your inbox. If you remove a filter, posts that were blocked
      while it was active will not appear in your timeline.
== paginate(env, terms)
h3.ui.dividing.header Add Content Filter Term
p
  | By default, filter terms match the <em>entire content</em> of a
    post <em>exactly</em>. Filter terms support wildcards "_" and "%".
    Wildcard "_" matches any single character and wildcard "%" matches
    zero or more consecutive characters.
p
  | To match a <em>single</em> percent character use "\\%". To match a
    <em>single</em> underscore use "\\_". To match the word "term" found
    anywhere inside the content of a post, use "%term%". To match posts
    that contain "elon" followed later by "musk" (like "Elon Musk says..."
    or "why Elon is... Musk's company..."), use "%elon%musk%".
- term = FilterTerm.new(term: "")
== form_tag(term, filters_path) do
  == error_messages(term)
  == input_tag("New Term", term, term)
  == submit_button
