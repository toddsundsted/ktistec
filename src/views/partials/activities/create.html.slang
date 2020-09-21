- _actor = activity.actor
- _author = activity.object.attributed_to? || _actor
- _object = activity.object
== render "src/views/partials/object.html.slang"
