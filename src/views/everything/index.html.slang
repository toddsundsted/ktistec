- content_for "title" do
  | Everything
h1 Everything
p
  | This page shows every post that has arrived at #{Ktistec.site},
    whether addressed to a local actor or not, except for posts that
    have have been blocked and posts from actors that have been
    blocked. It is the equivalent of other servers' <em>federated
    timeline</em>.
- if (env.params.query["page"]?.try(&.to_i) || 1) == 1
  turbo-stream-source src="/stream/everything"
section.ui.feed data-controller="icon-load-error"
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
