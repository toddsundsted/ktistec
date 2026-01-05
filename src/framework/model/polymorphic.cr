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

      # NOTE: a model alias is similar to a subclass, with exceptions:
      # significantly, queries executed via a subclass constrain their
      # results to the subclass and its subclasses. it is not possible
      # to do that with an alias, because there is no subclass on
      # which to make the call.

      macro finished
        {% for includer in @type.includers %}
          # Returns type and all concrete (non-abstract) subtypes,
          # including any aliases defined on the type.
          #
          def {{includer}}.all_subtypes
            \{% if @type.has_constant?("ALIASES") %}
              super + ALIASES
            \{% else %}
              super
            \{% end %}
          end
        {% end %}
      end
    end
  end
end
