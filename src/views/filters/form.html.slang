- content_for "title" do
  | Filters
h1 #{term.new_record? ? "Add" : "Edit"} Content Filter Term
== form_tag(term, filters_path) do
  == error_messages(term)
  == input_tag("Term", term, term)
  == submit_button
