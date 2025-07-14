require "school/rule/pattern"

# pick up function definitions
require "../utils/compiler"

require "./ext/sqlite3"
require "./model"

module Ktistec
  module Rule
    # Types supported by the SQLite client library.
    #
    alias SupportedType = String | Symbol | Float64 | Float32 | Int64 | Int32 | Char | Bool

    # Pairs composed of SQL conditions and values.
    #
    alias ConditionPair = Tuple(String, SupportedType | Array(SupportedType) | Nil)

    # Returns a SQL condition and values given an expression. The
    # supplied function must return an appropriate supported type (or
    # `nil`) given a rules domain type.
    #
    def self.condition(
         table : String,
         column : String,
         expression : School::Expression,
         bindings : School::Bindings,
         block : School::DomainTypes -> SupportedType?
       ) : ConditionPair?
      case expression
      when School::Lit
        if (term = block.call expression.target)
          { %Q|"#{table}"."#{column}" = ?|, term }
        else
          { %Q|"#{table}"."#{column}" IS NULL|, nil }
        end
      when School::Var
        if bindings.has_key?(expression.name)
          if (term = block.call bindings[expression.name])
            { %Q|"#{table}"."#{column}" = ?|, term }
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        else
          { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
        end
      when School::Not
        target = expression.target
        case target
        when School::Lit
          if (term = block.call target.target)
            { %Q|"#{table}"."#{column}" != ?|, term }
          else
            { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
          end
        when School::Var
          if bindings.has_key?(target.name)
            if (term = block.call bindings[target.name])
              { %Q|"#{table}"."#{column}" != ?|, term }
            else
              { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
            end
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        end
      when School::Within
        # if within contains an unbound var it will
        # effectively match anything. `wildcard` tracks
        # that.
        wildcard = false
        params = [] of String
        values = [] of SupportedType
        expression.targets.each do |target|
          case target
          when School::Lit
            if (term = block.call target.target)
              params << "?"
              values << term
            else
              params << "NULL"
            end
          when School::Var
            if bindings.has_key?(target.name)
              if (term = block.call bindings[target.name])
                params << "?"
                values << term
              else
                params << "NULL"
              end
            else
              wildcard = true
            end
          end
        end
        if wildcard
          { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
        else
          { %Q|"#{table}"."#{column}" IN (#{params.join(',')})|, values }
        end
      when Ktistec::Function::Strip
        target = expression.target
        case target
        when School::Lit
          if (term = block.call target.target)
            { %Q|"#{table}"."#{column}" = strip(?)|, term }
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        when School::Var
          if bindings.has_key?(target.name)
            if (term = block.call bindings[target.name])
              { %Q|"#{table}"."#{column}" = strip(?)|, term }
            else
              { %Q|"#{table}"."#{column}" IS NULL|, nil }
            end
          else
            { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
          end
        when School::Accessor
          if (term = block.call target.call(bindings))
            { %Q|"#{table}"."#{column}" = strip(?)|, term }
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        else
          raise "#{target.class} is unsupported"
        end
      when Ktistec::Function::Filter
        target = expression.target
        case target
        when School::Lit
          if (term = block.call target.target)
            { %Q|like("#{table}"."#{column}", ?, '\\')|, term }
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        when School::Var
          if bindings.has_key?(target.name)
            if (term = block.call bindings[target.name])
              { %Q|like("#{table}"."#{column}", ?, '\\')|, term }
            else
              { %Q|"#{table}"."#{column}" IS NULL|, nil }
            end
          else
            { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
          end
        when School::Accessor
          if (term = block.call target.call(bindings))
            { %Q|like("#{table}"."#{column}", ?, '\\')|, term }
          else
            { %Q|"#{table}"."#{column}" IS NULL|, nil }
          end
        when Ktistec::Function::Strip
          target = target.target
          case target
          when School::Lit
            if (term = block.call target.target)
              { %Q|like("#{table}"."#{column}", strip(?), '\\')|, term }
            else
              { %Q|"#{table}"."#{column}" IS NULL|, nil }
            end
          when School::Var
            if bindings.has_key?(target.name)
              if (term = block.call bindings[target.name])
                { %Q|like("#{table}"."#{column}", strip(?), '\\')|, term }
              else
                { %Q|"#{table}"."#{column}" IS NULL|, nil }
              end
            else
              { %Q|"#{table}"."#{column}" IS NOT NULL|, nil }
            end
          when School::Accessor
            if (term = block.call target.call(bindings))
              { %Q|like("#{table}"."#{column}", strip(?), '\\')|, term }
            else
              { %Q|"#{table}"."#{column}" IS NULL|, nil }
            end
          else
            raise "#{target.class} is unsupported"
          end
        else
          raise "#{target.class} is unsupported"
        end
      when School::Accessor
        if (term = block.call expression.call(bindings))
          { %Q|"#{table}"."#{column}" = ?|, term }
        else
          { %Q|"#{table}"."#{column}" IS NULL|, nil }
        end
      else
        raise "#{expression.class} is unsupported"
      end
    end

    # Makes a pattern class given a model class.
    #
    #   Ktistec::Rule.make_pattern(
    #     PatternClass,
    #     ModelClass,
    #     associations: [child_of],
    #     properties: [id, name]
    #   )
    #
    # In order to perform a match operation, pattern classes have to
    # transform literals and bound values into the types the SQLite
    # client library understands. This imposes constraints on types
    # that participating model properties may use. In the example
    # above, properties `id` and `name` must be one of the supported
    # types.
    #
    macro make_pattern(name, clazz, associations = nil, properties = nil)
      {% clazz = clazz.resolve %}

      class ::{{clazz}} ; include ::School::DomainType ; end

      class {{name.id}} < School::Pattern
        @vars = [] of String

        alias Supported = School::Lit | School::Var | School::Not | School::Within

        @options = {} of String => Supported

        def initialize(@target : Supported? = nil)
          if (target = @target).is_a?(School::Var)
            @vars << target.name
          end
        end

        def initialize(@target : Supported? = nil, **options : Supported)
          if (target = @target).is_a?(School::Var)
            @vars << target.name
          end
          options.each do |name, expression|
            @vars << expression.name if expression.is_a?(School::Var)
            @options[name.to_s] = expression
          end
        end

        def initialize(@target : Supported? = nil, options = {} of String => Supported)
          if (target = @target).is_a?(School::Var)
            @vars << target.name
          end
          options.each do |name, expression|
            @vars << expression.name if expression.is_a?(School::Var)
            @options[name] = expression
          end
        end

        # :inherit:
        def vars : Enumerable(String)
          @vars
        end

        # :inherit:
        def match(bindings : School::Bindings, trace : School::TraceNode? = nil, &block : School::Bindings -> Nil) : Nil
          match_all(bindings, trace).each do |temporary|
            yield temporary
          end
        end

        # note: accumulate all matches, first, and then yield them
        # one-by-one, instead of yielding them immediately to the
        # block as they are generated to reduce code inlining due to
        # block syntax and to reduce pressure on the stack (this
        # reduces stack frame size by a tenth over just yielding to
        # the block).

        private def match_all(bindings : School::Bindings, trace : School::TraceNode?) : Enumerable(School::Bindings)
          keys = @options.keys
          {% if associations %}
            keys -= {{associations.map(&.id.stringify)}}
          {% end %}
          {% if properties %}
            keys -= {{properties.map(&.id.stringify)}}
          {% end %}
          raise ArgumentError.new("invalid arguments: #{keys.join(",")}") unless keys.empty?

          table_name = {{clazz.id}}.table_name
          column_names = {{clazz.id}}.columns(table_name)

          conditions = [] of Ktistec::Rule::ConditionPair?

          if (target = @target)
            conditions << Ktistec::Rule.condition(table_name, "id", target, bindings, ->(value : School::DomainTypes) {
              if value.responds_to?(:id) && value.id
                value.id
              end
            })
          end

          {% if associations %}
            {% for association in associations %}
              {% ancestors = clazz.ancestors << clazz %}
              {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
              {% unless (method = methods.find { |d| d.name == "_association_#{association.id}" }) %}
                {% raise "#{association.id} is not an association on #{clazz}" %}
              {% end %}
              {% definition = method.body %}
              {% if definition[0] == :belongs_to %}
                if @options.has_key?({{association.id.stringify}})
                  conditions << Ktistec::Rule.condition(table_name, {{definition[2].id.stringify}}, @options[{{association.id.stringify}}], bindings, ->(value : School::DomainTypes) {
                    if value.responds_to?({{definition[1]}}) && value.{{definition[1].id}}
                      value.{{definition[1].id}}
                    end
                  })
                end
              {% else %}
                {% raise "#{definition[0]} associations are not supported" %}
              {% end %}
            {% end %}
          {% end %}

          {% if properties %}
            {% for property in properties %}
              {% derived_name = property %}
              {% ancestors = clazz.ancestors << clazz %}
              {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
              {% if (method = methods.find { |d| d.name == "_association_#{property.id}" }) %}
                {% if method.body[0] == :derived %}
                  {% derived_name = method.body[2] %}
                {% end %}
              {% end %}
              if @options.has_key?({{property.id.stringify}})
                conditions << Ktistec::Rule.condition(table_name, {{derived_name.id.stringify}}, @options[{{property.id.stringify}}], bindings, ->(value : School::DomainTypes) {
                  raise "values of type #{value.class} are currently unsupported" unless value.is_a?(Ktistec::Rule::SupportedType?)
                  value
                })
              end
            {% end %}
          {% end %}

          {% if clazz < Model::Undoable %}
            conditions << { %Q|#{table_name}."undone_at" IS NULL|, nil } unless @options.has_key?("undone_at")
          {% end %}
          {% if clazz < Model::Deletable %}
            conditions << { %Q|#{table_name}."deleted_at" IS NULL|, nil } unless @options.has_key?("deleted_at")
          {% end %}
          {% if clazz < Model::Polymorphic %}
            unless @options.has_key?("type")
              types = {{(clazz.all_subclasses << clazz).map(&.stringify).join("','")}}
              conditions << { %Q|#{table_name}."type" IN ('#{types}')|, nil }
            end
          {% end %}

          query = <<-SQL
          SELECT #{column_names} FROM #{table_name}
          SQL
          unless (conditions = conditions.compact).empty?
            query += " WHERE " + conditions.map(&.first).join(" AND ")
            args = conditions.map(&.last).flatten.compact
          end

          trace.condition(self) if trace

          {{clazz.id}}.sql(query, args).map do |model|
            bindings.dup.tap do |temporary|
              if (target = @target) && (name = target.name?) && !temporary.has_key?(name)
                temporary[name] = model
              end

              {% if associations %}
                {% for association in associations %}
                  if @options.has_key?({{association.id.stringify}})
                    if (target = @options[{{association.id.stringify}}]) && (name = target.name?) && !temporary.has_key?(name)
                      break unless (value = model.{{association.id}}?(include_deleted: true, include_undone: true))
                      temporary[name] = value
                    end
                  end
                {% end %}
              {% end %}

              {% if properties %}
                {% for property in properties %}
                  if @options.has_key?({{property.id.stringify}})
                    if (target = @options[{{property.id.stringify}}]) && (name = target.name?) && !temporary.has_key?(name)
                      break unless (value = model.{{property.id}})
                      temporary[name] = value
                    end
                  end
                {% end %}
              {% end %}

              trace.fact(model, bindings, temporary) if trace
            end
          end.compact
        end

        def self.assert(target : School::DomainTypes?, **options : School::DomainTypes)
          {{clazz}}.new(**options).save
        end

        def self.assert(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
          {{clazz}}.new(options).save
        end

        def self.retract(target : School::DomainTypes?, **options : School::DomainTypes)
          {{clazz}}.find(**options).destroy
        end

        def self.retract(target : School::DomainTypes?, options : Hash(String, School::DomainTypes))
          {{clazz}}.find(options).destroy
        end
      end
    end
  end
end
