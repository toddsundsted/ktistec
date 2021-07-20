require "../framework/controller"

module Ktistec::ViewHelper
  module ClassMethods
    def depth(object)
      "depth-#{Math.min(object.depth, 9)}"
    end

    def object_partial(env, object, actor = object.attributed_to, author = actor, *, with_detail = false, for_thread = nil)
      if for_thread
        render "src/views/partials/thread.html.slang"
      else
        render "src/views/partials/object.html.slang"
      end
    end
  end

  macro included
    extend ClassMethods
  end
end
