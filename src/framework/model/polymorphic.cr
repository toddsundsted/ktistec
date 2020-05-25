require "../model"

module Balloon
  module Model
    module Polymorphic
      macro find(_id id, *, as _as)
        {% raise "can't convert #{@type} to #{_as}" unless _as.resolve < @type %}
        {{_as}}.find({{id}}).tap do |inst|
          unless {{_as.stringify}} == inst.type
            raise TypeCastError.new("#{{{_as.stringify}}} != #{inst.type}")
          end
        end
      end

      macro find(*, as _as, **options)
        {% raise "can't convert #{@type} to #{_as}" unless _as.resolve < @type %}
        {{_as}}.find({{**options}}).tap do |inst|
          unless {{_as.stringify}} == inst.type
            raise TypeCastError.new("#{{{_as.stringify}}} != #{inst.type}")
          end
        end
      end

      def as_a(as _as : T.class) : T forall T
        {% raise "can't convert #{@type} to #{T}" unless T < @type %}
        T.find(self.id).tap do |inst|
          unless {{T.stringify}} == inst.type
            raise TypeCastError.new("#{{{T.stringify}}} != #{inst.type}")
          end
        end
      end

      @[Persistent]
      property type : String { {{@type.stringify}} }
    end
  end
end

module Polymorphic
end
