require "../model"

module Ktistec
  module Model
    module Polymorphic
      macro find(_id id, *, as _as)
        {% raise "can't convert #{@type} to #{_as}" unless _as.resolve < @type %}
        {{_as}}.find({{id}})
      end

      macro find(*, as _as, **options)
        {% raise "can't convert #{@type} to #{_as}" unless _as.resolve < @type %}
        {{_as}}.find({{**options}})
      end

      def as_a(as _as : T.class) : T forall T
        T.find(self.id)
      end

      @[Persistent]
      property type : String { {{@type.stringify}} }
    end
  end
end

# :nodoc:
module Polymorphic
end
