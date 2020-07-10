require "./framework"

module Balloon
  module Model(*T)
    # Marks properties as bulk assignable.
    #
    annotation Assignable
    end

    # Marks properties as insignificant (not part of identity).
    #
    annotation Insignificant
    end

    # Marks properties as persistent (and bulk assignable).
    #
    annotation Persistent
    end

    # Model utilities.
    #
    module Utils
      # Returns the table name, given a model.
      #
      def self.table_name(clazz)
        (name = clazz.to_s.gsub("::", "").underscore) +
          if name.ends_with?(/s|ss|sh|ch|x|z/)
            "es"
          else
            "s"
          end
      end
    end

    module ClassMethods
      # Returns the table name.
      #
      def table_name
        @@table_name ||= Utils.table_name(self)
      end

      # Returns true if no instances exist.
      #
      def empty?
        count == 0
      end

      # Returns the count of saved instances.
      #
      def count(**options)
        if options.empty?
          Balloon.database.scalar(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT COUNT(*) FROM #{table_name} WHERE type IN (%s)" %
              {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}}
            {% else %}
              "SELECT COUNT(*) FROM #{table_name}"
            {% end %}
          ).as(Int)
        else
          {% begin %}
            {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
            conditions = options.keys.select do |o|
              o.in?({{vs.map(&.symbolize)}})
            end.map do |v|
              "#{v} = ?"
            end.join(" AND ")
            Balloon.database.scalar(
              {% if @type < Balloon::Model::Polymorphic %}
                "SELECT COUNT(*) FROM #{table_name} WHERE type IN (%s) AND #{conditions}" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
              {% else %}
                "SELECT COUNT(*) FROM #{table_name} WHERE #{conditions}",
              {% end %}
              *options.values
            ).as(Int)
          {% end %}
        end
      end

      private def compose(rs : DB::ResultSet)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          attrs = {
            {% for v in vs %}
              {{v}}: rs.read({{v.type}}),
            {% end %}
          }
          {% if @type < Balloon::Model::Polymorphic %}
            case attrs[:type]
            {% for subclass in @type.all_subclasses %}
              when {{subclass.stringify}}
                {{subclass}}.new(**attrs)
            {% end %}
            else
              self.new(**attrs)
            end
          {% else %}
            self.new(**attrs)
          {% end %}
        {% end %}
      end

      # Returns all instances.
      #
      def all
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          Balloon.database.query_all(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT #{columns} FROM #{table_name} WHERE type IN (%s)" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
            {% else %}
              "SELECT #{columns} FROM #{table_name}",
            {% end %}
            &->compose(DB::ResultSet)
          )
        {% end %}
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(_id id : Int?)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          conditions = "id = ?"
          Balloon.database.query_one(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT #{columns} FROM #{table_name} WHERE type IN (%s) AND #{conditions}" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
            {% else %}
              "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            {% end %}
            id,
            &->compose(DB::ResultSet)
          )
        {% end %}
      rescue ex: DB::Error
        raise NotFound.new if ex.message == "no rows"
        raise ex
      end

      # Finds the saved instance.
      #
      # Returns `nil` if no such saved instance exists.
      #
      def find?(_id id : Int?)
        find(id)
      rescue NotFound
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(**options)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          conditions = options.keys.select do |o|
            o.in?({{vs.map(&.symbolize)}})
          end.map do |v|
            "#{v} = ?"
          end.join(" AND ")
          Balloon.database.query_one(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT #{columns} FROM #{table_name} WHERE type IN (%s) AND #{conditions}" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
            {% else %}
              "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            {% end %}
            *options.values,
            &->compose(DB::ResultSet)
          )
        {% end %}
      rescue ex: DB::Error
        raise NotFound.new if ex.message == "no rows"
        raise ex
      end

      # Finds the saved instance.
      #
      # Returns `nil` if no such saved instance exists.
      #
      def find?(**options)
        find(**options)
      rescue NotFound
      end

      # Returns saved instances.
      #
      def where(**options)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          conditions = options.keys.select do |o|
            o.in?({{vs.map(&.symbolize)}})
          end.map do |v|
            "#{v} = ?"
          end.join(" AND ")
          Balloon.database.query_all(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT #{columns} FROM #{table_name} WHERE type IN (%s) AND #{conditions}" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
            {% else %}
              "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            {% end %}
            *options.values,
            &->compose(DB::ResultSet)
          )
        {% end %}
      end

      # Returns saved instances.
      #
      def where(conditions : String, *arguments)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          Balloon.database.query_all(
            {% if @type < Balloon::Model::Polymorphic %}
              "SELECT #{columns} FROM #{table_name} WHERE type IN (%s) AND #{conditions}" %
                {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
            {% else %}
              "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            {% end %}
            *arguments,
            &->compose(DB::ResultSet)
          )
        {% end %}
      end
    end

    module InstanceMethods
      # Initializes the new instance.
      #
      def initialize(**options)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            if (o = options[{{v.symbolize}}]?)
              self.{{v}} = o
            end
          {% end %}
        {% end %}
        super
      end

      # Returns true if all properties are equal.
      #
      def ==(other : self)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Persistent) && !v.annotation(Insignificant) } %}
          if
            {% for v in vs %}
              self.{{v}} == other.{{v}} &&
            {% end %}
            self.id == other.id
            true
          else
            false
          end
        {% end %}
      end

      # Bulk assigns properties.
      #
      def assign(**options)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            if (o = options[{{v.symbolize}}]?)
              self.{{v}} = o
            end
          {% end %}
        {% end %}
        self
      end

      # Returns the table name.
      #
      def table_name
        @@table_name ||= Utils.table_name(self.class)
      end

      getter errors = Errors.new

      # Returns true if the instance is valid.
      #
      def valid?
        validate.empty?
      end

      # Validates the instance and returns any errors.
      #
      def validate
        @errors.clear
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          {% for v in vs %}
            if self.responds_to?(:_validate_{{v}})
              if error = self._validate_{{v}}(self.{{v}})
                @errors[{{v.stringify}}] = [error]
              end
            end
          {% end %}
          {% for d in @type.methods.select { |d| d.name.starts_with?("_belongs_to_") } %}
            if (%body = {{d.body}})
              if %body.responds_to?(:each)
                %body.each_with_index do |b, i|
                  if (errors = b.validate)
                    errors = errors.transform_keys { |k| "{{d.name[12..-1]}}.#{i}.#{k}" }
                    @errors.merge!(errors)
                  end
                end
              else
                if (errors = %body.validate)
                  errors = errors.transform_keys { |k| "{{d.name[12..-1]}}.#{k}" }
                  @errors.merge!(errors)
                end
              end
            end
          {% end %}
        {% end %}
        @errors
      end

      # Adds a validation to a property on an instance.
      #
      #     validates xyz { "is blank" if xyz.blank? }
      #
      macro validates(property, &block)
        private def _validate_{{property.name}}({{property.name}})
          {% if block %}
            {{block.body}}
          {% else %}
            {{property.block.body}}
          {% end %}
        end
      end

      # Specifies a one-to-one association with another model.
      #
      macro belongs_to(name, primary_key = id, foreign_key = nil, class_name = nil)
        {% begin %}
          {% foreign_key = foreign_key || "#{name}_id".id %}
          {% class_name = class_name || name.stringify.camelcase.id %}
          @[Assignable]
          @{{name}} : {{class_name}}?
          def {{name}}=(@{{name}} : {{class_name}})
            self.{{foreign_key}} = {{name}}.{{primary_key}}.as(typeof(self.{{foreign_key}}))
            {{name}}
          end
          def {{name}}?
            @{{name}} ||= {{class_name}}.find?({{primary_key}}: self.{{foreign_key}})
          end
          def {{name}}
            @{{name}} ||= {{class_name}}.find({{primary_key}}: self.{{foreign_key}})
          end
          def _belongs_to_{{name}}
            @{{name}}
          end
        {% end %}
      end

      # Specifies a one-to-many association with another model.
      #
      macro has_many(name, primary_key = id, foreign_key = nil, class_name = nil)
        {% begin %}
          {% singular = name.stringify %}
          {% singular = singular =~ /(ses|sses|shes|ches|xes|zes)$/ ? singular[0..-3] : singular[0..-2] %}
          {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
          {% class_name = class_name || singular.camelcase.id %}
          @[Assignable]
          @{{name}} : Enumerable({{class_name}})?
          def {{name}}=(@{{name}} : Enumerable({{class_name}}))
            {{name}}.each { |n| n.{{foreign_key}} = self.{{primary_key}}.as(typeof(n.{{foreign_key}})) }
            {{name}}
          end
          def {{name}}
            {{name}} = @{{name}}
            if {{name}}.nil? || {{name}}.empty?
              @{{name}} = {{class_name}}.where({{foreign_key}}: self.{{primary_key}})
            end
            @{{name}}.not_nil!
          end
          def _belongs_to_{{name}}
            @{{name}}
          end
        {% end %}
      end

      # Specifies a one-to-one association with another model.
      #
      macro has_one(name, primary_key = id, foreign_key = nil, class_name = nil)
        {% begin %}
          {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
          {% class_name = class_name || name.stringify.camelcase.id %}
          @[Assignable]
          @{{name}} : {{class_name}}?
          def {{name}}=(@{{name}} : {{class_name}})
            {{name}}.{{foreign_key}} = self.{{primary_key}}.as(typeof({{name}}.{{foreign_key}}))
            {{name}}
          end
          def {{name}}?
            @{{name}} ||= {{class_name}}.find?({{foreign_key}}: self.{{primary_key}})
          end
          def {{name}}
            @{{name}} ||= {{class_name}}.find({{foreign_key}}: self.{{primary_key}})
          end
          def _belongs_to_{{name}}
            @{{name}}
          end
        {% end %}
      end

      # Specifies a serializer for a column.
      #
      macro serializes(name, format = json, to_method = nil, from_method = nil, column_name = nil, class_name = nil)
        {% begin %}
          {% to_method = to_method || "to_#{format}".id %}
          {% from_method = from_method || "from_#{format}".id %}
          {% column_name = column_name || "#{name}_#{format}".id %}
          {% class_name = class_name || name.stringify.capitalize.id %}
          def {{name}}=({{name}} : {{class_name}})
            self.{{column_name}} = {{name}}.{{to_method}}
            {{name}}
          end
          def {{name}}
            if {{column_name}} = self.{{column_name}}
              {{class_name}}.{{from_method}}({{column_name}})
            end
          end
        {% end %}
      end

      # Saves the instance.
      #
      def save
        raise Invalid.new(errors) unless valid?
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          if @id
            if self.responds_to?(:updated_at=)
              self.updated_at = Time.utc
            end
            conditions = {{vs.map(&.stringify.stringify)}}.map do |v|
              "#{v} = ?"
            end.join(",")
            Balloon.database.exec(
              "UPDATE #{table_name} SET #{conditions} WHERE id = ?",
              {% for v in vs %}
                self.{{v}},
              {% end %}
              @id
            )
          else
            columns = {{vs.map(&.stringify.stringify).join(",")}}
            conditions = (["?"] * {{vs.size}}).join(",")
            @id = Balloon.database.exec(
              "INSERT INTO #{table_name} (#{columns}) VALUES (#{conditions})",
              {% for v in vs %}
                self.{{v}},
              {% end %}
            ).last_insert_id
          end
          {% for d in @type.methods.select { |d| d.name.starts_with?("_belongs_to_") } %}
            if (%body = {{d.body}})
              %body.responds_to?(:each) ? %body.each(&.save) : %body.save
            end
          {% end %}
        {% end %}
        self
      end

      # Destroys the instance.
      #
      def destroy
        Balloon.database.exec("DELETE FROM #{table_name} WHERE id = ?", @id)
        @id = nil
        self
      end

      def to_json(json : JSON::Builder)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          json.object do
            {% for v in vs %}
              json.field({{v.stringify}}, {{v}})
            {% end %}
          end
        {% end %}
      end

      def to_s(io : IO)
        super
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          {% for v in vs %}
            io << " " << {{v.stringify}} << "=" << {{v}}.inspect
          {% end %}
        {% end %}
      end

      def to_h
        {% begin %}
          {
            {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
            {% for v in vs %}
              {{v.stringify}} => {{v}},
            {% end %}
          }
        {% end %}
      end

      @@table_name : String?
    end

    macro included
      extend ClassMethods
      include InstanceMethods

      {% for type in T.type_vars %}
        include ::Balloon::Model::{{type}}
      {% end %}
    end

    @[Persistent]
    property id : Int64? = nil

    class Error < Exception
    end

    class NotFound < Exception
    end

    class Invalid < Exception
      def initialize(errors : Errors)
        message = errors.map { |field, error| "#{field}: #{error.join(", ")}" }.join("; ")
        initialize(message)
      end
    end

    alias Errors = Hash(String, Array(String))
  end
end

require "./model/**"
require "../models/**"
