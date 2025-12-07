- content_for "title" do
  = title
- if related.empty? && title == "Followers"
  .ui.basic.very.padded.center.aligned.segment
    - if env.account?
      .ui.icon.header
        i.exclamation.icon
        | No one is following you, yet.
      .ui.text
        | This page lists your followers.
    - else
      .ui.icon.header
        i.exclamation.icon
        | There is nothing here, yet.
- elsif related.empty? && title == "Following"
  .ui.basic.very.padded.center.aligned.segment
    - if env.account?
      .ui.icon.header
        i.exclamation.icon
        | You're not following anyone, yet.
      .ui.text
        | This page lists people you are following.
    - else
      .ui.icon.header
        i.exclamation.icon
        | There is nothing here, yet.
- else
  h1= title
  section.ui.cards
    - related.each do |actor|
      == render "src/views/partials/actor-card.html.slang"
  == paginate(env, related)
