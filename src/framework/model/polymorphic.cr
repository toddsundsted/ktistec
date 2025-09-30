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
        {{_as}}.find({{options.double_splat}})
      end

      def as_a(as _as : T.class) : T forall T
        T.find(self.id)
      end

      @[Persistent]
      property type : String { {{@type.stringify}} }

      # NOTE: this is implemented as if it had been created by the
      # `validates` macro because the `validates` macro is not
      # available if this module is being tested alone.

      def _validate_type
        {% begin %}
          {%
            all_types = [@type.stringify]
            all_types += @type.all_subclasses.map(&.stringify)
            if @type.has_constant?(:ALIASES)
              all_types += @type.constant(:ALIASES)
            end
          %}
          "is not valid" unless type.in?({{all_types}})
        {% end %}
      end
    end
  end
end
