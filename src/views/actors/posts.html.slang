- content_for "title" do
  | Posts
- if objects.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists your published posts and shares.
        You should go to <a href="#{actor_path}">your home page</a> and write something.
- else
  h1 Posts
  section.ui.feed data-controller="icon-load-error"
    - objects.each do |object|
      crystal:
        activity = object.activities.find do |activity|
          Relationship::Content::Outbox.find?(owner: actor, activity: activity)
        end
        _actor = activity ? activity.actor : object.attributed_to
        _author = object.attributed_to
      == object_partial(env, object, activity: activity, actor: _actor, author: _author)
  == paginate(env, objects)
