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

    macro persistent_columns
      {
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        {% for v in vs %}
          {{v.id}}: {{v.type}},
        {% end %}
      }
    end

    module ClassMethods
      # Returns the table name.
      #
      def table_name
        @@table_name ||= Util.pluralize(self.to_s.gsub("::", "").underscore)
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

      def values(options : Hash(String, Any)? = nil, **options_) forall Any
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          (options || options_).map do |o, v|
            if o.to_s.in?({{vs.map(&.stringify)}})
              v
            {% ancestors = @type.ancestors << @type %}
            {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
            {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
            {% for method in methods %}
              elsif "_association_#{o}" == {{method.name.stringify}} && v.responds_to?({{method.body[1]}})
                v.{{method.body[1].id}}
            {% end %}
            else
              raise ColumnError.new("no such column: #{o}")
            end
          end
        {% end %}
      end

      def conditions(*terms, include_deleted : Bool = false, include_undone : Bool = false, options : Hash(String, Any)? = nil, **options_) forall Any
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          conditions =
            (options || options_).keys.reduce([] of String) do |c, o|
              if o.to_s.in?({{vs.map(&.stringify)}})
                c << %Q|"#{o}" = ?|
              {% ancestors = @type.ancestors << @type %}
              {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
              {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
              {% for method in methods %}
                elsif "_association_#{o}" == {{method.name.stringify}}
                  c << %Q|"#{{{method.body[2]}}}" = ?|
              {% end %}
              else
                raise ColumnError.new("no such column: #{o}")
              end
              c
            end
          {% if @type < Deletable %}
            conditions << %Q|"deleted_at" IS NULL| unless include_deleted
          {% end %}
          {% if @type < Undoable %}
            conditions << %Q|"undone_at" IS NULL| unless include_undone
          {% end %}
          {% if @type < Polymorphic %}
            conditions << %Q|"type" IN (%s)| % {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}}
          {% end %}
          conditions += terms.to_a
          conditions.size > 0 ?
            conditions.join(" AND ") :
            "1"
        {% end %}
      end

      # Returns the count of saved instances.
      #
      def count(include_deleted : Bool = false, include_undone : Bool = false, **options)
        Ktistec.database.scalar(
          "SELECT COUNT(id) FROM #{table} WHERE #{conditions(**options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(**options)
        ).as(Int)
      end

      # Returns the count of saved instances.
      #
      def count(options : Hash(String, Any), include_deleted : Bool = false, include_undone : Bool = false) forall Any
        Ktistec.database.scalar(
          "SELECT COUNT(id) FROM #{table} WHERE #{conditions(options: options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(options: options)
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

      # specialize the following to avoid a compile bug?
      # see: https://github.com/crystal-lang/crystal/issues/7164

      protected def query_all(query, *args_, additional_columns = NamedTuple.new)
        Ktistec.database.query_all(
          query, *args_,
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.map do |options|
          compose(**options)
        end
      end

      protected def query_all(query, args : Array? = nil, additional_columns = NamedTuple.new)
        Ktistec.database.query_all(
          query, args: args,
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.map do |options|
          compose(**options)
        end
      end

      protected def query_one(query, *args_, additional_columns = NamedTuple.new)
        Ktistec.database.query_one(
          query, *args_,
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.try do |options|
          compose(**options)
        end
      end

      protected def query_one(query, args : Array? = nil, additional_columns = NamedTuple.new)
        Ktistec.database.query_one(
          query, args: args,
        ) do |rs|
          read(rs, **persistent_columns.merge(additional_columns))
        end.try do |options|
          compose(**options)
        end
      end

      # Returns all instances.
      #
      def all(include_deleted : Bool = false, include_undone : Bool = false)
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(include_deleted: include_deleted, include_undone: include_undone)}")
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(_id id : Int?, include_deleted : Bool = false, include_undone : Bool = false)
        query_one("SELECT #{columns} FROM #{table} WHERE #{conditions(id: id, include_deleted: include_deleted, include_undone: include_undone)}", id)
      rescue DB::NoResultsError
        raise NotFound.new("#{self} id=#{id}: not found")
      end

      # Finds the saved instance.
      #
      # Returns `nil` if no such saved instance exists.
      #
      def find?(_id id : Int?, include_deleted : Bool = false, include_undone : Bool = false)
        find(id, include_deleted: include_deleted, include_undone: include_undone)
      rescue NotFound
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(include_deleted : Bool = false, include_undone : Bool = false, **options)
        query_one("SELECT #{columns} FROM #{table} WHERE #{conditions(**options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(**options))
      rescue DB::NoResultsError
        raise NotFound.new("#{self} options=#{options}: not found")
      end

      # Finds the saved instance.
      #
      # Returns `nil` if no such saved instance exists.
      #
      def find?(include_deleted : Bool = false, include_undone : Bool = false, **options)
        find(**options, include_deleted: include_deleted, include_undone: include_undone)
      rescue NotFound
      end

      # Finds the saved instance.
      #
      # Raises `NotFound` if no such saved instance exists.
      #
      def find(options : Hash(String, Any), include_deleted : Bool = false, include_undone : Bool = false) forall Any
        query_one("SELECT #{columns} FROM #{table} WHERE #{conditions(options: options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(options: options))
      rescue DB::NoResultsError
        raise NotFound.new("#{self} options=#{options}: not found")
      end

      # Finds the saved instance.
      #
      # Returns `nil` if no such saved instance exists.
      #
      def find?(options : Hash(String, Any), include_deleted : Bool = false, include_undone : Bool = false) forall Any
        find(options, include_deleted: include_deleted, include_undone: include_undone)
      rescue NotFound
      end

      # Returns saved instances.
      #
      def where(include_deleted : Bool = false, include_undone : Bool = false, **options)
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(**options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(**options))
      end

      # Returns saved instances.
      #
      def where(options : Hash(String, Any), include_deleted : Bool = false, include_undone : Bool = false) forall Any
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(options: options, include_deleted: include_deleted, include_undone: include_undone)}", args: values(options: options))
      end

      # Returns saved instances.
      #
      def where(where : String, *arguments, include_deleted : Bool = false, include_undone : Bool = false)
        query_all("SELECT #{columns} FROM #{table} WHERE #{conditions(where, include_deleted: include_deleted, include_undone: include_undone)}", *arguments)
      end

      # Runs the query.
      #
      def sql(query : String, *arguments)
        query_all(query, *arguments)
      end
    end

    module InstanceMethods
      # Initializes the new instance.
      #
      def initialize(options : Hash(String, Any)) forall Any
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        super()
        # dup but don't maintain a linked list of previously saved records
        @saved_record = self.dup.clear_saved_record
      end

      # Initializes the new instance.
      #
      def initialize(**options)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        super()
        # dup but don't maintain a linked list of previously saved records
        @saved_record = self.dup.clear_saved_record
      end

      # Bulk assigns properties.
      #
      def assign(options : Hash(String, Any)) forall Any
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                @changed << {{v.symbolize}}
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
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                @changed << {{v.symbolize}}
                self.{{v}} = o
              end
            end
          {% end %}
        {% end %}
        self
      end

      # Returns true if all persistent properties are equal.
      #
      def ==(other)
        if other.is_a?(self)
          {% begin %}
            {% vs = @type.instance_vars.select { |v| v.annotation(Persistent) && !v.annotation(Insignificant) } %}
            self.same?(other) || ({{vs.map { |v| "self.#{v} == other.#{v}" }.join(" && ").id}})
          {% end %}
        else
          false
        end
      end

      # Returns the table name.
      #
      def table_name
        self.class.table_name
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
          changed!({{name.symbolize}})
          self.{{foreign_key}} = {{name}}.{{primary_key}}.as(typeof(self.{{foreign_key}}))
          {{name}}
        end
        def {{name}}?(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}?
          @{{name}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key}}: self.{{foreign_key}}, include_deleted: include_deleted, include_undone: include_undone) ||
            {% end %}
            nil
          end
        end
        def {{name}}(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}
          @{{name}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key}}: self.{{foreign_key}}, include_deleted: include_deleted, include_undone: include_undone) ||
            {% end %}
            raise NotFound.new("#{self.class} {{name}} {{primary_key}}=#{self.{{foreign_key}}}: not found")
          end
        end
        def _association_{{name}}
          {:belongs_to, {{primary_key.symbolize}}, {{foreign_key.symbolize}}, {{class_name}}, @{{name}}}
        end
      end

      # Specifies a one-to-many association with another model.
      #
      macro has_many(name, primary_key = id, foreign_key = nil, class_name = nil, inverse_of = nil)
        {% singular = name.stringify %}
        {% singular = singular =~ /(ses|sses|shes|ches|xes|zes)$/ ? singular[0..-3] : singular[0..-2] %}
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || singular.camelcase.id %}
        @[Assignable]
        @{{name}} : Array({{class_name}})?
        def {{name}}=({{name}} : Enumerable({{class_name}})) : Enumerable({{class_name}})
          @{{name}} = {{name}}.to_a
          changed!({{name.symbolize}})
          {{name}}.each do |n|
            n.{{foreign_key}} = self.{{primary_key}}.as(typeof(n.{{foreign_key}}))
            {% if inverse_of %}
              n.{{inverse_of}} = self
            {% end %}
          end
          {{name}}
        end
        def {{name}}(include_deleted : Bool = false, include_undone : Bool = false) : Enumerable({{class_name}})
          {{name}} = @{{name}}
          if {{name}}.nil? || {{name}}.empty?
            @{{name}} = {{class_name}}.where({{foreign_key}}: self.{{primary_key}}, include_deleted: include_deleted, include_undone: include_undone)
          end
          @{{name}}.not_nil!
        end
        def _association_{{name}}
          {:has_many, {{primary_key.symbolize}}, {{foreign_key.symbolize}}, Enumerable({{class_name}}), @{{name}}}
        end
      end

      # Specifies a one-to-one association with another model.
      #
      macro has_one(name, primary_key = id, foreign_key = nil, class_name = nil, inverse_of = nil)
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || name.stringify.camelcase.id %}
        @[Assignable]
        @{{name}} : {{class_name}}?
        def {{name}}=({{name}} : {{class_name}}) : {{class_name}}
          @{{name}} = {{name}}
          changed!({{name.symbolize}})
          {{name}}.{{foreign_key}} = self.{{primary_key}}.as(typeof({{name}}.{{foreign_key}}))
          {% if inverse_of %}
            {{name}}.{{inverse_of}} = self
          {% end %}
          {{name}}
        end
        def {{name}}?(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}?
          @{{name}} ||= {{class_name}}.find?({{foreign_key}}: self.{{primary_key}}, include_deleted: include_deleted, include_undone: include_undone)
        end
        def {{name}}(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}
          @{{name}} ||= {{class_name}}.find({{foreign_key}}: self.{{primary_key}}, include_deleted: include_deleted, include_undone: include_undone)
        end
        def _association_{{name}}
          {:has_one, {{primary_key.symbolize}}, {{foreign_key.symbolize}}, {{class_name}}, @{{name}}}
        end
      end

      record(
        Node,
        model : Model::InstanceMethods,
        association : String?,
        index : Int32?
      )

      def serialize_graph(skip_associated = false)
        ([] of Node).tap do |result|
          _serialize_graph(result, skip_associated: skip_associated)
        end
      end

      def _serialize_graph(result, association = nil, index = nil, skip_associated = false)
        return if self.destroyed?
        {% if @type < Deletable %}
          return if self.deleted?
        {% end %}
        {% if @type < Undoable %}
          return if self.undone?
        {% end %}
        result << Node.new(self, association, index)
        {% begin %}
          {% ancestors = @type.ancestors << @type %}
          {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
          {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
          unless skip_associated
            options = {skip_associated: skip_associated}
            {% for method in methods %}
              if (%body = {{method.body}}.last)
                if %body.responds_to?(:each)
                  %body.each_with_index do |model, i|
                    unless result.any? { |node| model == node.model }
                      model._serialize_graph(result, {{method.name[13..-1].stringify}}, i, **options)
                    end
                  end
                else
                  unless result.any? { |node| %body == node.model }
                    %body._serialize_graph(result, {{method.name[13..-1].stringify}}, **options)
                  end
                end
              end
            {% end %}
          end
        {% end %}
      end

      private macro run_callback(callback, skip_associated = false, nodes = nil)
        %nodes = [] of Node
        # iteratively run lifecycle callbacks, which can add new
        # associated models, which must be processed in turn
        loop do
          %new = serialize_graph(skip_associated: skip_associated)
          %delta = %new - %nodes
          %nodes = %new
          break if %delta.empty?
          %delta.each do |%node|
            if (%model = %node.model) && %model.responds_to?({{callback.symbolize}})
              %model.{{callback}}
            end
          end
        end
        # return the serialize graph
        {{nodes}} = %nodes if {{nodes}}
      end

      getter errors = Errors.new

      # Returns true if the instance is valid.
      #
      def valid?(skip_associated = false)
        validate(skip_associated: skip_associated).empty?
      end

      # Validates the instance and returns any errors.
      #
      def validate(skip_associated = false)
        @errors.clear
        nodes = [] of Node
        run_callback(before_validate, skip_associated: skip_associated, nodes: nodes)
        nodes.each do |node|
          if (errors = node.model._run_validations)
            if (association = node.association)
              if (index = node.index)
                errors = errors.transform_keys { |key| "#{association}.#{index}.#{key}" }
              else
                errors = errors.transform_keys { |key| "#{association}.#{key}" }
              end
            end
            @errors.merge!(errors)
          end
        end
        run_callback(after_validate, skip_associated: skip_associated, nodes: nodes)
        @errors
      end

      def _run_validations
        @errors.clear
        {% begin %}
          if self.responds_to?(:validate_model)
            self.validate_model
          end
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            if self.responds_to?(:_validate_{{v}})
              if error = self._validate_{{v}}
                @errors[{{v.stringify}}] = [error]
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
        private def _validate_{{property.name}}
          {% if block %}
            {{block.body}}
          {% else %}
            {{property.block.body}}
          {% end %}
        end
      end

      # Saves the instance.
      #
      def save(skip_validation = false, skip_associated = false)
        raise Invalid.new(errors) unless skip_validation || valid?(skip_associated: skip_associated)
        nodes = [] of Node
        run_callback(before_save, skip_associated: skip_associated, nodes: nodes)
        nodes.each do |node|
          node.model._save_model(skip_validation: skip_validation)
        end
        run_callback(after_save, skip_associated: skip_associated, nodes: nodes)
        self
      end

      def _save_model(skip_validation = false)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          conditions = (["?"] * {{vs.size}}).join(",")
          if self.responds_to?(:updated_at=)
            self.updated_at = Time.utc
          end
          @id = Ktistec.database.exec(
            "INSERT OR REPLACE INTO #{table_name} (#{columns}) VALUES (#{conditions})",
            {% for v in vs %}
              self.{{v}},
            {% end %}
          ).last_insert_id
        {% end %}
        # destroy unassociated instances
        {% begin %}
          {% ancestors = @type.ancestors << @type %}
          {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
          {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
          if (saved_record = @saved_record)
            {% for method in methods %}
              {% name = method.name[13..-1] %}
              {% if method.body.first == :has_one %}
                if (self.changed?({{name.symbolize}}))
                  if (model = saved_record.{{name}}?)
                    model.destroy unless self.{{name}} == model
                  end
                end
              {% elsif method.body.first == :has_many %}
                if (self.changed?({{name.symbolize}}))
                  saved_record.{{name}}.each do |model|
                    model.destroy unless self.{{name}}.includes?(model)
                  end
                end
              {% end %}
            {% end %}
          end
        {% end %}
        # dup but don't maintain a linked list of previously saved records
        @saved_record = self.dup.clear_saved_record
        clear!
      end

      getter? destroyed = false

      # Destroys the instance.
      #
      def destroy
        self.before_destroy if self.responds_to?(:before_destroy)
        Ktistec.database.exec("DELETE FROM #{table_name} WHERE id = ?", @id)
        self.after_destroy if self.responds_to?(:after_destroy)
        @destroyed = true
        @id = nil
        self
      end

      def new_record?
        @id.nil?
      end

      @changed = Set(Symbol).new

      def changed!(property : Symbol)
        @changed << property
      end

      def changed?(property : Symbol? = nil)
        new_record? || (property ? @changed.includes?(property) : !@changed.empty?)
      end

      def clear!(property : Symbol? = nil)
        property ? @changed.delete(property) : @changed.clear
      end

      protected def clear_saved_record
        @saved_record = nil
        self
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
        {% unless type == ::Nil %}
          include ::Ktistec::Model::{{type}}
        {% end %}
      {% end %}

      @saved_record : self | Nil = nil
    end

    @[Persistent]
    property id : Int64? = nil

    class NotFound < Exception
    end

    class ColumnError < Exception
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
require "./model/undoable"
require "./model/polymorphic"
