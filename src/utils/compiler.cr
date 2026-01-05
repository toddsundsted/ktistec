require "school"

require "./parser"

module Ktistec
  class Compiler
    # Creates a compiler for the given input.
    #
    def initialize(input : String)
      @parser = Parser.new(input)
    end

    # Compiles the input into a domain with rules.
    #
    def compile
      School::Domain.new.tap do |domain|
        @parser.statements.each do |statement|
          if statement.is_a?(RuleDefinition)
            patterns = [] of School::BasePattern
            actions = [] of School::Action
            statement.patterns.each do |pattern|
              arguments = pattern.arguments.map do |argument|
                compile_expression(argument)
              end
              options = pattern.options.transform_values do |value|
                compile_expression(value)
              end
              case pattern.id
              when "condition"
                patterns << instantiate(pattern.constant.id, arguments, options)
              when "any"
                pattern = instantiate(pattern.constant.id, arguments, options)
                patterns << School::Pattern::Any.new(pattern)
              when "none"
                pattern = instantiate(pattern.constant.id, arguments, options)
                patterns << School::Pattern::None.new(pattern)
              when "assert"
                actions << School::Action.new do |_, context|
                  assert(pattern.constant.id, context, arguments, options)
                end
              when "retract"
                actions << School::Action.new do |_, context|
                  retract(pattern.constant.id, context, arguments, options)
                end
              else
                # this should never happen
              end
            end
            rule = School::Rule.new(statement.name, patterns, actions, trace: statement.trace)
            domain.add(rule)
          end
        end
      end
    end

    class ::Ktistec::Function::Strip < School::Expression
      include School::Atomic

      getter target

      def initialize(@target : School::Atomic, name : String? = nil)
        self.name = name if name
      end

      # :inherit:
      def ==(other : self)
        self.target == other.target
      end
    end

    class ::Ktistec::Function::Filter < School::Expression
      getter target

      def initialize(@target : School::Atomic, name : String? = nil)
        self.name = name if name
      end

      # :inherit:
      def ==(other : self)
        self.target == other.target
      end
    end

    private def compile_expression(node : Ktistec::Node) : School::Expression
      case node
      when Ktistec::Literal
        return School::Lit.new(node.token.value)
      when Ktistec::Identifier
        return School::Var.new(node.token.as_s)
      when Ktistec::PrefixOperator
        case node.id
        when "not"
          if (exp = compile_expression(node.right)).is_a?(School::Matcher)
            return School::Not.new(exp)
          else
            raise LinkError.new(self, "argument must be a matcher")
          end
        end
      when Ktistec::InfixOperator
        case node.id
        when "."
          return accessor(node.left.id, node.right.id)
        end
      when Ktistec::FunctionOperator
        case node.left.id
        when "within"
          right = node.right.map do |arg|
            if (exp = compile_expression(arg)).is_a?(School::Atomic)
              exp.as(School::Atomic)
            else
              raise LinkError.new(self, "argument must be atomic")
            end
          end
          return School::Within.new(right)
        when "strip"
          raise LinkError.new(self, "wrong number of arguments: strip") if node.right.size != 1
          if (exp = compile_expression(node.right.first)).is_a?(School::Atomic)
            return Function::Strip.new(exp)
          else
            raise LinkError.new(self, "argument must be atomic")
          end
        when "filter"
          raise LinkError.new(self, "wrong number of arguments: filter") if node.right.size != 1
          if (exp = compile_expression(node.right.first)).is_a?(School::Atomic)
            return Function::Filter.new(exp)
          else
            raise LinkError.new(self, "argument must be atomic")
          end
        end
      end
      raise LinkError.new(self, "unsupported expression")
    end

    private def transform_arguments(bindings, arguments)
      arguments.map do |value|
        case value
        when School::Lit
          value.target
        when School::Var
          bindings[value.name]
        else
          raise LinkError.new(self, "#{value.class} is unsupported in actions")
        end
      end
    end

    private def transform_options(bindings, options)
      options.transform_values do |value|
        case value
        when School::Lit
          value.target
        when School::Var
          bindings[value.name]
        else
          raise LinkError.new(self, "#{value.class} is unsupported in actions")
        end
      end
    end

    # dispatchers for actions on constants. the following line
    # normally wouldn't compile ("can't use Class as generic type
    # argument yet"), however `CONSTANTS` is only used inside of
    # macros--no code is generated.

    CONSTANTS = [] of Class

    macro register_constant(clazz)
      {% CONSTANTS << clazz.resolve %}
    end

    macro finished
      private def instantiate(name, arguments, options)
        case name
        {% for clazz in CONSTANTS %}
          when {{clazz.id.stringify.split("::").last}}
            {% if clazz < School::Pattern %}
              raise LinkError.new(self, "too many arguments") if arguments.size > 1
              {{clazz}}.new(arguments[0]?, options)
            {% elsif clazz < School::Relationship %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 2
              School::BinaryPattern.new({{clazz}}, arguments[0], arguments[1])
            {% elsif clazz < School::Property %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 1
              School::UnaryPattern.new({{clazz}}, arguments[0])
            {% elsif clazz < School::Fact %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 0
              School::NullaryPattern.new({{clazz}})
            {% end %}
        {% end %}
        else
          raise LinkError.new(self, "undefined constant: #{name}")
        end
      end
      private def assert(name, context, arguments, options)
        case name
        {% for clazz in CONSTANTS %}
          when {{clazz.stringify.split("::").last}}
            {% if clazz < School::Pattern %}
              raise LinkError.new(self, "too many arguments") if arguments.size > 1
              {{clazz}}.assert(transform_arguments(context.bindings, arguments)[0]?, transform_options(context.bindings, options))
            {% elsif clazz < School::Relationship %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 2
              arguments = transform_arguments(context.bindings, arguments)
              a = arguments[0].as({{clazz.ancestors[0].type_vars[0]}})
              b = arguments[1].as({{clazz.ancestors[0].type_vars[1]}})
              context.facts.add({{clazz}}.new(a, b))
            {% elsif clazz < School::Property %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 1
              arguments = transform_arguments(context.bindings, arguments)
              c = arguments[0].as({{clazz.ancestors[0].type_vars[0]}})
              context.facts.add({{clazz}}.new(c))
            {% elsif clazz < School::Fact %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 0
              context.facts.add({{clazz}}.new)
            {% end %}
        {% end %}
        else
          raise LinkError.new(self, "undefined constant: #{name}")
        end
      end
      private def retract(name, context, arguments, options)
        case name
        {% for clazz in CONSTANTS %}
          when {{clazz.stringify.split("::").last}}
            {% if clazz < School::Pattern %}
              raise LinkError.new(self, "too many arguments") if arguments.size > 1
              {{clazz}}.retract(transform_arguments(context.bindings, arguments)[0]?, transform_options(context.bindings, options))
            {% elsif clazz < School::Relationship %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 2
              arguments = transform_arguments(context.bindings, arguments)
              a = arguments[0].as({{clazz.ancestors[0].type_vars[0]}})
              b = arguments[1].as({{clazz.ancestors[0].type_vars[1]}})
              context.facts.delete({{clazz}}.new(a, b))
            {% elsif clazz < School::Property %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 1
              arguments = transform_arguments(context.bindings, arguments)
              c = arguments[0].as({{clazz.ancestors[0].type_vars[0]}})
              context.facts.delete({{clazz}}.new(c))
            {% elsif clazz < School::Fact %}
              raise LinkError.new(self, "too many arguments") if arguments.size != 0
              context.facts.delete({{clazz}}.new)
            {% end %}
        {% end %}
        else
          raise LinkError.new(self, "undefined constant: #{name}")
        end
      end
    end

    # dispatcher for accessors.

    ACCESSOR = [] of Class

    macro register_accessor(name)
      {% ACCESSOR << name.id %}
    end

    macro finished
      private def accessor(key, name)
        case name
        {% for accessor in ACCESSOR %}
          when {{accessor.stringify}}
            School::Accessor.new do |bindings|
              if bindings.has_key?(key)
                if (object = bindings[key]).responds_to?({{accessor.symbolize}})
                  object.{{accessor}}
                else
                  raise LinkError.new(self, "invalid accessor: {{accessor}}")
                end
              else
                raise LinkError.new(self, "unbound receiver: #{key}")
              end
            end
        {% end %}
        else
          raise LinkError.new(self, "undefined accessor: #{name}")
        end
      end
    end

    # Raised to indicate a link error.
    #
    class LinkError < Exception
      def initialize(@compiler : Compiler, message : String)
        super(message)
      end
    end
  end
end
