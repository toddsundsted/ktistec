require "../framework/controller"

module Ktistec::ViewHelper
  def depth(object)
    "depth-#{Math.min(object.depth, 9)}"
  end

  def object_partial(env, object, actor = object.attributed_to, author = actor, *, for_thread = nil)
    if for_thread
      render "src/views/partials/thread.html.slang"
    else
      render "src/views/partials/object.html.slang"
    end
  end
end
