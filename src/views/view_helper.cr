require "../framework/controller"

module Ktistec::ViewHelper
  def object_partial(env, _object, _actor = _object.attributed_to, _author = _actor)
    render "src/views/partials/object.html.slang"
  end
end
