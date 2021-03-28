require "../framework/controller"

module Ktistec::ViewHelper
  def object_partial(env, object, actor = object.attributed_to, author = actor)
    render "src/views/partials/object.html.slang"
  end
end
