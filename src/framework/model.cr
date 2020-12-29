require "./framework"
require "./util"

module Ktistec
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

    macro persistent_columns(prefix = nil)
      {
        {% prefix = prefix ? "#{prefix.id}." : "" %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        {% for v in vs %}
          "{{prefix.id}}{{v.id}}": {{v.type}},
        {% end %}
      }
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

      def table(as_name = nil)
        as_name = as_name ? " AS \"#{as_name}\"" : ""
        "\"#{table_name}\"#{as_name}"
      end

      def columns(prefix = nil)
        prefix = prefix ? "\"#{prefix}\"." : ""
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)).map(&.stringify.stringify) %}
          {{vs}}.map { |v| "#{prefix}#{v}" }.join(",")
        {% end %}
      end

      def conditions(*terms, prefix = nil, **options)
        prefix = prefix ? "\"#{prefix}\"." : ""
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          conditions =
            [
              {% if @type < Deletable %}
                "#{prefix}\"deleted_at\" IS NULL",
              {% end %}
              {% if @type < Polymorphic %}
                "#{prefix}\"type\" IN (%s)" % {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}},
              {% end %}
            ] of String +
            options.keys.select { |o| o.in?({{vs.map(&.symbolize)}}) }.map { |v| "#{prefix}\"#{v}\" = ?" } +
            terms.to_a
          conditions.size > 0 ?
            conditions.join(" AND ") :
            "1"
        {% end %}
      end

      # Returns the count of saved instances.
      #
      def count(**options)
        Ktistec.database.scalar(
          "SELECT COUNT(id) FROM #{table} WHERE #{conditions(**options)}", *options.values
        ).as(Int)
      end

      def persistent_columns
        {% begin %}
          {
            {% for v in @type.instance_vars.select(&.annotation(Persistent)) %}
              {{v}}: {{v.type}},
            {% end %}
          }
        {% end %}
      end

      private def read(rs : DB::ResultSet, **types : **T) forall T
        {% begin %}
          {
            {% for name, type in T %}
              "{{name}}": rs.read({{type.instance}}),
            {% end %}
          }
        {% end %}
      end

      private def compose(**options) : self
        options = options.to_h.transform_keys(&.to_s.as(String))
        {% begin %}
          {% if @type < Polymorphic %}
            case options["type"]
            {% for subclass in @type.all_subclasses %}
              when {{subclass.stringify}}
                {{subclass}}.new(options)
            {% end %}
            else
              self.new(options)
            end
          {% else %}
            self.new(options)
          {% end %}
        {% end %}
      end

      # Note: The following query helpers process query results in two
      # steps, first (within the scope of the database call) mapping
      # named tuples, and then (in a separate block) creating
      # instances. This is intentional. Model initializers can make
      # database calls, and nested database calls currently crash the
      # runtime.

      protected def query_and_paginate(query, *args, additional_columns = NamedTuple.new, page = 1, size = 10)
        Ktistec::Util::PaginatedArray(self).new.tap do |array|
          Ktistec.database.query(
            query, *args, ((page - 1) * size).to_i, size.to_i + 1
          ) do |rs|
            ([] of typeof(read(rs, **persistent_columns.merge(additional_columns)))).tap do |array|
              rs.each { array << read(rs, **persistent_columns.merge(additional_columns)) }
            end
          end.each do |options|
            array << compose(**options)
          end
          if array.size > size
            array.more = true
            array.pop
          end
        end
      end

      protected def query_all(query, *args, additional_columns = NamedTuple.new)
        Ktistec.database.query_all(
          query, *args
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.map do |options|
          compose(**options)
        end
      end

      protected def query_one(query, *args, additional_columns = NamedTuple.new)
        Ktistec.database.query_one(
          query, *args
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.try do |options|
          compose(**options)
        end
      end

      # Returns all instances.
      #
      def all
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions}")
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(_id id : Int?)
        query_one("SELECT #{columns} FROM #{table} WHERE #{conditions(id: id)}", id)
      rescue ex: DB::Error
        raise NotFound.new("#{self}: #{id}") if ex.message == "no rows"
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
        query_one("SELECT #{columns} FROM #{table} WHERE #{conditions(**options)}", *options.values)
      rescue ex: DB::Error
        raise NotFound.new("#{self}: #{options}") if ex.message == "no rows"
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
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(**options)}", *options.values)
      end

      # Returns saved instances.
      #
      def where(where : String, *arguments)
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(where)}", *arguments)
      end
    end

    module InstanceMethods
      @saved_record : self | Nil = nil

      # Initializes the new instance.
      #
      def initialize(options : Hash, prefix : String = "")
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = prefix + {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]?).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        super()
      end

      # Initializes the new instance.
      #
      def initialize(**options)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]?).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        super()
      end

      # Bulk assigns properties.
      #
      def assign(options : Hash, prefix : String = "")
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = prefix + {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]?).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        self
      end

      # Bulk assigns properties.
      #
      def assign(**options)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]?).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        self
      end

      # Returns true if all persistent properties are equal.
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

      # Returns the table name.
      #
      def table_name
        @@table_name ||= Utils.table_name(self.class)
      end

      getter errors = Errors.new

      # Returns true if the instance is valid.
      #
      def valid?(skip_autosave = false)
        validate(skip_autosave: skip_autosave).empty?
      end

      # Validates the instance and returns any errors.
      #
      def validate(skip_autosave = false)
        @errors.clear
        {% if @type < Deletable %}
          return @errors if self.deleted?
        {% end %}
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            if self.responds_to?(:_validate_{{v}})
              if error = self._validate_{{v}}
                @errors[{{v.stringify}}] = [error]
              end
            end
          {% end %}
          unless skip_autosave
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
          end
        {% end %}
        @errors
      end

      # Adds a validation to a property on an instance.
      #
      #     validates xyz { "is blank" if xyz.blank? }
      #
      macro validates(property, &block)
        private def _validate_{{property.name}}
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
        {% foreign_key = foreign_key || "#{name}_id".id %}
        {% class_name = class_name ? class_name.id : name.stringify.camelcase.id %}
        {% union_types = class_name.split("|").map(&.strip.id) %}
        @[Assignable]
        @{{name}} : {{class_name}}?
        def {{name}}=(@{{name}} : {{class_name}}) : {{class_name}}
          self.{{foreign_key}} = {{name}}.{{primary_key}}.as(typeof(self.{{foreign_key}}))
          {{name}}
        end
        def {{name}}? : {{class_name}}?
          @{{name}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key}}: self.{{foreign_key}}) ||
            {% end %}
            nil
          end
        end
        def {{name}} : {{class_name}}
          @{{name}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key}}: self.{{foreign_key}}) ||
            {% end %}
            raise NotFound.new
          end
        end
        def _belongs_to_{{name}} : {{class_name}}
          @{{name}}
        end
      end

      # Specifies a one-to-many association with another model.
      #
      macro has_many(name, primary_key = id, foreign_key = nil, class_name = nil)
        {% singular = name.stringify %}
        {% singular = singular =~ /(ses|sses|shes|ches|xes|zes)$/ ? singular[0..-3] : singular[0..-2] %}
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || singular.camelcase.id %}
        @[Assignable]
        @{{name}} : Enumerable({{class_name}})?
        def {{name}}=(@{{name}} : Enumerable({{class_name}})) : Enumerable({{class_name}})
          {{name}}.each { |n| n.{{foreign_key}} = self.{{primary_key}}.as(typeof(n.{{foreign_key}})) }
          {{name}}
        end
        def {{name}} : Enumerable({{class_name}})
          {{name}} = @{{name}}
          if {{name}}.nil? || {{name}}.empty?
            @{{name}} = {{class_name}}.where({{foreign_key}}: self.{{primary_key}})
          end
          @{{name}}.not_nil!
        end
        def _belongs_to_{{name}} : Enumerable({{class_name}})
          @{{name}}
        end
      end

      # Specifies a one-to-one association with another model.
      #
      macro has_one(name, primary_key = id, foreign_key = nil, class_name = nil)
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || name.stringify.camelcase.id %}
        @[Assignable]
        @{{name}} : {{class_name}}?
        def {{name}}=(@{{name}} : {{class_name}}) : {{class_name}}
          {{name}}.{{foreign_key}} = self.{{primary_key}}.as(typeof({{name}}.{{foreign_key}}))
          {{name}}
        end
        def {{name}}? : {{class_name}}?
          @{{name}} ||= {{class_name}}.find?({{foreign_key}}: self.{{primary_key}})
        end
        def {{name}} : {{class_name}}
          @{{name}} ||= {{class_name}}.find({{foreign_key}}: self.{{primary_key}})
        end
        def _belongs_to_{{name}} : {{class_name}}
          @{{name}}
        end
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
      def save(skip_validation = false, skip_autosave = false)
        {% if @type < Deletable %}
          return self if self.deleted?
        {% end %}
        raise Invalid.new(errors) unless skip_validation || valid?(skip_autosave: skip_autosave)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          conditions = (["?"] * {{vs.size}}).join(",")
          if self.responds_to?(:updated_at=)
            self.updated_at = Time.utc
          end
          if @id
            Ktistec.database.exec(
              "INSERT OR REPLACE INTO #{table_name} (#{columns}) VALUES (#{conditions})",
              {% for v in vs %}
                self.{{v}},
              {% end %}
            )
          else
            @id = Ktistec.database.exec(
              "INSERT INTO #{table_name} (#{columns}) VALUES (#{conditions})",
              {% for v in vs %}
                self.{{v}},
              {% end %}
            ).last_insert_id
          end
          {% ancestors = @type.ancestors << @type %}
          {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
          {% methods = methods.select { |d| d.name.starts_with?("_belongs_to_") } %}
          unless skip_autosave
            options = {skip_validation: skip_validation, skip_autosave: skip_autosave}
            {% for d in methods %}
              if (%body = {{d.body}})
                %body.responds_to?(:each) ? %body.each(&.save(**options)) : %body.save(**options)
              end
            {% end %}
          end
        {% end %}
        @saved_record = self.dup
        self
      end

      # Destroys the instance.
      #
      def destroy
        Ktistec.database.exec("DELETE FROM #{table_name} WHERE id = ?", @id)
        @id = nil
        self
      end

      def new_record?
        @id.nil?
      end

      def changed?
        @saved_record ||= self.class.find?(@id)
        @saved_record != self
      end

      def to_json(json : JSON::Builder)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          json.object do
            {% for v in vs %}
              json.field({{v.stringify}}, self.{{v}})
            {% end %}
          end
        {% end %}
      end

      def to_s(io : IO)
        super
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          {% for v in vs %}
            io << " " << {{v.stringify}} << "=" << self.{{v}}.inspect
          {% end %}
        {% end %}
      end

      def to_h
        {% begin %}
          {
            {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
            {% for v in vs %}
              {{v.stringify}} => self.{{v}},
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
        include ::Ktistec::Model::{{type}}
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

require "./model/deletable"
require "./model/polymorphic"
