- content_for "title" do
  | Drafts
- if drafts.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists your draft posts.
        You should go to <a href="#{actor_path}">your home page</a> and write something.
- else
  h1 Drafts
  section.ui.feed
    - drafts.each do |object|
      == object_partial(env, object)
  == paginate(env, drafts)
