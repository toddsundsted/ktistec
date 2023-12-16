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

      # Returns table name in format suitable for building queries.
      #
      def table(as_name = nil)
        as_name = as_name ? %Q| AS "#{as_name}"| : ""
        %Q|"#{table_name}"#{as_name}|
      end

      # Returns table columns in format suitable for building queries.
      #
      def columns(prefix = nil)
        prefix = prefix ? %Q|"#{prefix}".| : ""
        {% begin %}
          vs = {{ @type.instance_vars.select(&.annotation(Persistent)).map(&.stringify.stringify) }}
          if self < Polymorphic
            vs = [%q|"type"|] + vs
          end
          if (table_columns = @@table_columns)
            vs = vs + table_columns.map(&.inspect)
          end
          vs.map { |v| "#{prefix}#{v}" }.join(",")
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
                  c << %Q|"{{method.body[2].id}}" = ?|
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
          # by convention, a class that inherits directly from
          # `Reference` is the *base class* of a class hierarchy.
          # therefore, it isn't necessary to restrict rows to specific
          # subclasses, since all rows and all subclasses should
          # belong to the hierarchy and should be included.
          {% if @type < Polymorphic && @type.superclass != Reference %}
            conditions << %Q|"type" IN (%s)| % {{(@type.all_subclasses << @type).map(&.stringify.stringify).join(",")}}
          {% end %}
          conditions += terms.to_a
          conditions.size > 0 ?
            conditions.join(" AND ") :
            "1"
        {% end %}
      end

      # Returns type and all subtypes.
      #
      def all_subtypes
        {{(@type.all_subclasses << @type).map(&.stringify)}}
      end

      # Logs query performance.
      #
      # Times a database call and result processing and selectively
      # emits a log message. The severity is based on the total
      # duration.
      #
      protected def log_query(query, args)
        start = Time.monotonic
        result = yield
        finish = Time.monotonic
        delta = (finish - start).total_milliseconds
        if delta > 50
          Log.warn { |log| format_message("Slow query", log, delta, query, args) }
        else
          Log.debug { |log| format_message("Query", log, delta, query, args) }
        end
        result
      end

      private def format_message(message, log, delta, query, args)
        delta = sprintf("%10.3fms", delta)
        query = query.each_line.map(&.strip).join(" ")
        args = DB::MetadataValueConverter.arg_to_log(args)
        log.emit(
          "#{message} [#{delta}] -- #{query}",
          args: args
        )
      end

      # Returns the count of saved instances.
      #
      def count(include_deleted : Bool = false, include_undone : Bool = false, **options)
        query = "SELECT COUNT(id) FROM #{table} WHERE #{conditions(**options, include_deleted: include_deleted, include_undone: include_undone)}"
        args = values(**options)
        log_query(query, args) do
          Ktistec.database.scalar(
            query, args: args
          ).as(Int)
        end
      end

      # Returns the count of saved instances.
      #
      def count(options : Hash(String, Any), include_deleted : Bool = false, include_undone : Bool = false) forall Any
        query = "SELECT COUNT(id) FROM #{table} WHERE #{conditions(options: options, include_deleted: include_deleted, include_undone: include_undone)}"
        args = values(options: options)
        log_query(query, args) do
          Ktistec.database.scalar(
            query, args: args
          ).as(Int)
        end
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

      # Compose an instance of the correct type from the query results.
      #
      # Invokes the protected __for_internal_use_only initializer to
      # instantiate the instance.
      #
      private def compose(rs : DB::ResultSet, **additional_columns) : self
        {% begin %}
          # for polymorphic models, instantiate the correct subclass
          # _and_ ensure that any properties defined _only_ on the
          # subclass are populated.
          {% if @type < Polymorphic %}
            case rs.read(String) # type
            {% for subclass in @type.all_subclasses %}
              when {{subclass.stringify}}
                {% if subclass.abstract? %}
                  raise TypeError.new("cannot instantiate abstract model {{subclass}}")
                {% else %}
                  options = rs.read(**self.persistent_columns.merge(additional_columns)).to_h
                  {% temp = @type.instance_vars.select(&.annotation(Persistent)).map(&.name) %}
                  {% vars = subclass.instance_vars.select(&.annotation(Persistent)).reject { |d| temp.includes?(d.name) } %}
                  {% unless vars.empty? %}
                    if (table_columns = @@table_columns)
                      table_columns.each do |column|
                        case column
                        {% for v in vars %}
                        when {{v.stringify}}
                          options = options.merge({ {{v.name.symbolize}} => rs.read({{v.type}}) })
                        {% end %}
                        else
                          rs.read # discard, it's not a property
                        end
                      end
                    end
                  {% end %}
                  {{subclass}}.allocate.tap do |instance|
                    instance.__for_internal_use_only(options).clear!
                  end
                {% end %}
            {% end %}
            {% if @type.abstract? %}
              else
                raise TypeError.new("cannot instantiate abstract model {{@type}}")
            {% else %}
              else
                options = rs.read(**self.persistent_columns.merge(additional_columns))
                self.allocate.tap do |instance|
                  instance.__for_internal_use_only(options).clear!
                end
            {% end %}
            end
          {% else %}
            {% if @type.abstract? %}
              raise TypeError.new("cannot instantiate abstract model {{@type}}")
            {% else %}
              options = rs.read(**self.persistent_columns.merge(additional_columns))
              self.allocate.tap do |instance|
                instance.__for_internal_use_only(options).clear!
              end
            {% end %}
          {% end %}
        {% end %}
      end

      protected def query_and_paginate(query, *args, additional_columns = NamedTuple.new, page = 1, size = 10)
        log_query(query, args) do
          Ktistec::Util::PaginatedArray(self).new.tap do |array|
            Ktistec.database.query(
              query, *args, ((page - 1) * size).to_i, size.to_i + 1
            ) do |rs|
              rs.each { array << compose(rs, **additional_columns) }
            end
            if array.size > size
              array.more = true
              array.pop
            end
          end
        end
      end

      # specialize the following to avoid a compile bug?
      # see: https://github.com/crystal-lang/crystal/issues/7164

      protected def query_all(query, *args_, additional_columns = NamedTuple.new)
        log_query(query, args_) do
          Ktistec.database.query_all(
            query, *args_
          ) do |rs|
            compose(rs, **additional_columns)
          end
        end
      end

      protected def query_all(query, args : Array? = nil, additional_columns = NamedTuple.new)
        log_query(query, args) do
          Ktistec.database.query_all(
            query, args: args
          ) do |rs|
            compose(rs, **additional_columns)
          end
        end
      end

      protected def query_one(query, *args_, additional_columns = NamedTuple.new)
        log_query(query, args_) do
          Ktistec.database.query_one(
            query, *args_
          ) do |rs|
            compose(rs, **additional_columns)
          end
        end
      end

      protected def query_one(query, args : Array? = nil, additional_columns = NamedTuple.new)
        log_query(query, args) do
          Ktistec.database.query_one(
            query, args: args
          ) do |rs|
            compose(rs, **additional_columns)
          end
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
      # Returns the result.
      #
      def scalar(query : String, *args_)
        log_query(query, args_) do
          Ktistec.database.scalar(query, *args_)
        end
      end

      # Runs the query.
      #
      # Returns the result.
      #
      def scalar(query : String, args : Array? = nil)
        log_query(query, args) do
          Ktistec.database.scalar(query, args: args)
        end
      end

      # Runs the query.
      #
      # Returns the number of rows affected.
      #
      def exec(query : String, *args_)
        log_query(query, args_) do
          Ktistec.database.exec(query, *args_).rows_affected
        end
      end

      # Runs the query.
      #
      # Returns the number of rows affected.
      #
      def exec(query : String, args : Array? = nil)
        log_query(query, args) do
          Ktistec.database.exec(query, args: args).rows_affected
        end
      end

      # Runs the query.
      #
      # Returns saved instances.
      #
      def sql(query : String, *arguments)
        query_all(query, *arguments)
      end
    end

    module InstanceMethods
      @changed : Set(Symbol)

      # Initializes the new instance.
      #
      # Sets instance variables directly to skip side effects.
      #
      protected def __for_internal_use_only(options)
        @changed = Set(Symbol).new
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.symbolize}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(@{{v}}))
                @{{v}} = o
              end
            end
          {% end %}
        {% end %}
        # dup but don't maintain a linked list of previously saved records
        @saved_record = self.dup.clear_saved_record
      end

      private def to_sentence(type)
        type = type.to_s
        types = (type.match(/^\((.+)\)$/).try(&.[1]) || type).split("|").map(&.strip)
        Util.to_sentence(types, last_word_connector: " or ")
      end

      # Initializes the new instance.
      #
      def initialize(options : Hash(String, Any)) forall Any
        @changed = Set(Symbol).new
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                @changed << {{v.symbolize}}
                if self.responds_to?({{"#{v}=".id.symbolize}})
                  self.{{v}} = o.as(typeof(self.{{v}}))
                else
                  raise TypeError.new("#{self.class}.new: property '#{key}' lacks a setter and may not be assigned")
                end
              else
                raise TypeError.new("#{self.class}.new: #{o.inspect} (#{o.class}) is not a #{to_sentence(typeof(self.{{v}}))} for property '#{key}'")
              end
            end
          {% end %}
          {% for v in vs %}
            key = {{v.stringify}}
            {% unless v.has_default_value? || v.type.nilable? || v.type.struct? %}
              unless {{v.symbolize}}.in?(@changed)
                raise TypeError.new("#{self.class}.new: property '#{key}' is not nilable and must be assigned")
              end
            {% end %}
          {% end %}
        {% end %}
        super()
        # dup but don't maintain a linked list of previously saved records
        @saved_record = self.dup.clear_saved_record
      end

      # Initializes the new instance.
      #
      def initialize(**options)
        @changed = Set(Symbol).new
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Assignable) || v.annotation(Persistent) } %}
          {% for v in vs %}
            key = {{v.stringify}}
            if options.has_key?(key)
              if (o = options[key]).is_a?(typeof(self.{{v}}))
                @changed << {{v.symbolize}}
                if self.responds_to?({{"#{v}=".id.symbolize}})
                  self.{{v}} = o.as(typeof(self.{{v}}))
                else
                  raise TypeError.new("#{self.class}.new: property '#{key}' lacks a setter and may not be assigned")
                end
              else
                raise TypeError.new("#{self.class}.new: #{o.inspect} (#{o.class}) is not a #{to_sentence(typeof(self.{{v}}))} for property '#{key}'")
              end
            end
          {% end %}
          {% for v in vs %}
            key = {{v.stringify}}
            {% unless v.has_default_value? || v.type.nilable? || v.type.struct? %}
              unless {{v.symbolize}}.in?(@changed)
                raise TypeError.new("#{self.class}.new: property '#{key}' is not nilable and must be assigned")
              end
            {% end %}
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
                if self.responds_to?({{"#{v}=".id.symbolize}})
                  self.{{v}} = o.as(typeof(self.{{v}}))
                else
                  raise TypeError.new("#{self.class}.new: property '#{key}' lacks a setter and may not be assigned")
                end
              else
                raise TypeError.new("#{self.class}.new: #{o.inspect} (#{o.class}) is not a #{to_sentence(typeof(self.{{v}}))} for property '#{key}'")
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
                if self.responds_to?({{"#{v}=".id.symbolize}})
                  self.{{v}} = o.as(typeof(self.{{v}}))
                else
                  raise TypeError.new("#{self.class}.new: property '#{key}' lacks a setter and may not be assigned")
                end
              else
                raise TypeError.new("#{self.class}.new: #{o.inspect} (#{o.class}) is not a #{to_sentence(typeof(self.{{v}}))} for property '#{key}'")
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

      # Computes the hash for this instance.
      #
      def hash(hasher)
        {% begin %}
          {% vs = @type.instance_vars.select { |v| v.annotation(Persistent) && !v.annotation(Insignificant) } %}
          {% for v in vs %}
            hasher = self.{{v}}.hash(hasher)
          {% end %}
        {% end %}
        hasher
      end

      # Returns the table name.
      #
      def table_name
        self.class.table_name
      end

      # Specifies a property that is derived from another property.
      #
      macro derived(decl, *, aliased_to)
        @[Assignable]
        @{{decl.var}} : {{decl.type}}?
        def {{decl.var}}=({{decl.var}} : {{decl.type}}) : {{decl.type}}
          @{{decl.var}} = @{{aliased_to}} = {{decl.var}}
          changed!({{decl.var.symbolize}}, {{aliased_to.symbolize}})
          {{decl.var}}
        end
        def {{decl.var}} : {{decl.type}}
          @{{decl.var}} = @{{aliased_to}}
        end
        def _association_{{decl.var}}
          {:derived, :itself, {{aliased_to.symbolize}}, {{decl.type}}, @{{decl.var}}}
        end
      end

      # Specifies a one-to-one association with another model.
      #
      macro belongs_to(name, primary_key = id, foreign_key = nil, class_name = nil, inverse_of = nil)
        {% foreign_key = foreign_key || "#{name.id}_id".id %}
        {% class_name = class_name ? class_name.id : name.id.stringify.camelcase.id %}
        {% union_types = class_name.split("|").map(&.strip.id) %}
        @[Assignable]
        @{{name.id}} : {{class_name}}?
        def {{name.id}}=({{name.id}}_ : {{class_name}}) : {{class_name}}
          _belongs_to_setter_for_{{name.id}}({{name.id}}_)
        end
        def _belongs_to_setter_for_{{name.id}}({{name.id}}_ : {{class_name}}, update_associations = true) : {{class_name}}
          @{{name.id}} = {{name.id}}_
          changed!({{name.id.symbolize}}, {{foreign_key.id.symbolize}})
          self.{{foreign_key.id}} = {{name.id}}_.{{primary_key.id}}.as(typeof(self.{{foreign_key.id}}))
          {% if inverse_of %}
            if update_associations
              if {{name.id}}_.responds_to?(:_has_one_setter_for_{{inverse_of.id}})
                {{name.id}}_._has_one_setter_for_{{inverse_of.id}}(self, false)
              elsif {{name.id}}_.responds_to?(:_has_many_setter_for_{{inverse_of.id}})
                {{name.id}}_._has_many_setter_for_{{inverse_of.id}}({{name.id}}_.{{inverse_of.id}} << self, false)
              end
              {{name.id}}_.clear!({{inverse_of.id.symbolize}})
            end
          {% end %}
          {{name.id}}_
        end
        def {{name.id}}?(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}?
          @{{name.id}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key.id}}: self.{{foreign_key.id}}, include_deleted: include_deleted, include_undone: include_undone) ||
            {% end %}
            nil
          end
        end
        def {{name.id}}(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}
          @{{name.id}} ||= begin
            {% for union_type in union_types %}
              {{union_type}}.find?({{primary_key.id}}: self.{{foreign_key.id}}, include_deleted: include_deleted, include_undone: include_undone) ||
            {% end %}
            raise NotFound.new("#{self.class} {{name.id}} {{primary_key.id}}=#{self.{{foreign_key.id}}}: not found")
          end
        end
        def _association_{{name.id}}
          {:belongs_to, {{primary_key.id.symbolize}}, {{foreign_key.id.symbolize}}, {{class_name}}, @{{name.id}}}
        end
      end

      # Specifies a one-to-many association with another model.
      #
      macro has_many(name, primary_key = id, foreign_key = nil, class_name = nil, inverse_of = nil)
        {% singular = name.id.stringify %}
        {% singular = singular =~ /(ses|sses|shes|ches|xes|zes)$/ ? singular[0..-3] : singular[0..-2] %}
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || singular.camelcase.id %}
        @[Assignable]
        @{{name.id}} : Array({{class_name}})?
        def {{name.id}}=({{name.id}}_ : Enumerable({{class_name}})) : Enumerable({{class_name}})
          _has_many_setter_for_{{name.id}}({{name.id}}_)
        end
        def _has_many_setter_for_{{name.id}}({{name.id}}_ : Enumerable({{class_name}}), update_associations = true) : Enumerable({{class_name}})
          @{{name.id}} = {{name.id}}_.to_a
          changed!({{name.id.symbolize}})
          {{name.id}}_.each do |n|
            n.{{foreign_key.id}} = self.{{primary_key.id}}.as(typeof(n.{{foreign_key.id}}))
            {% if inverse_of %}
              if update_associations
                n._belongs_to_setter_for_{{inverse_of.id}}(self, false)
                n.clear!({{inverse_of.id.symbolize}}, {{foreign_key.id.symbolize}})
              end
            {% end %}
          end
          {{name.id}}_
        end
        def {{name.id}}(include_deleted : Bool = false, include_undone : Bool = false) : Enumerable({{class_name}})
          {{name.id}} = @{{name.id}}
          if {{name.id}}.nil? || {{name.id}}.empty?
            @{{name.id}} = {{class_name}}.where({{foreign_key.id}}: self.{{primary_key.id}}, include_deleted: include_deleted, include_undone: include_undone)
          end
          @{{name.id}}.not_nil!
        end
        def _association_{{name.id}}
          {:has_many, {{primary_key.id.symbolize}}, {{foreign_key.id.symbolize}}, Enumerable({{class_name}}), @{{name.id}}}
        end
      end

      # Specifies a one-to-one association with another model.
      #
      macro has_one(name, primary_key = id, foreign_key = nil, class_name = nil, inverse_of = nil)
        {% foreign_key = foreign_key || "#{@type.stringify.split("::").last.underscore.id}_id".id %}
        {% class_name = class_name || name.id.stringify.camelcase.id %}
        @[Assignable]
        @{{name.id}} : {{class_name}}?
        def {{name.id}}=({{name.id}}_ : {{class_name}}) : {{class_name}}
          _has_one_setter_for_{{name.id}}({{name.id}}_)
        end
        def _has_one_setter_for_{{name.id}}({{name.id}}_ : {{class_name}}, update_associations = true) : {{class_name}}
          @{{name.id}} = {{name.id}}_
          changed!({{name.id.symbolize}})
          {{name.id}}_.{{foreign_key.id}} = self.{{primary_key.id}}.as(typeof({{name.id}}_.{{foreign_key.id}}))
          {% if inverse_of %}
            if update_associations
              {{name.id}}_._belongs_to_setter_for_{{inverse_of.id}}(self, false)
              {{name.id}}_.clear!({{inverse_of.id.symbolize}}, {{foreign_key.id.symbolize}})
            end
          {% end %}
          {{name.id}}_
        end
        def {{name.id}}?(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}?
          @{{name.id}} ||= {{class_name}}.find?({{foreign_key.id}}: self.{{primary_key.id}}, include_deleted: include_deleted, include_undone: include_undone)
        end
        def {{name.id}}(include_deleted : Bool = false, include_undone : Bool = false) : {{class_name}}
          @{{name.id}} ||= {{class_name}}.find({{foreign_key.id}}: self.{{primary_key.id}}, include_deleted: include_deleted, include_undone: include_undone)
        end
        def _association_{{name.id}}
          {:has_one, {{primary_key.id.symbolize}}, {{foreign_key.id.symbolize}}, {{class_name}}, @{{name.id}}}
        end
      end

      record(
        Node,
        # use InstanceMethods because Model is parameterized
        model : Model::InstanceMethods,
        association : String?,
        index : Int32?
      )

      def serialize_graph(skip_associated = false)
        ([] of Node).tap do |nodes|
          _serialize_graph(nodes, skip_associated: skip_associated)
        end
      end

      def _serialize_graph(nodes, association = nil, index = nil, skip_associated = false)
        return if self.destroyed?
        {% if @type < Deletable %}
          return if self.deleted?
        {% end %}
        {% if @type < Undoable %}
          return if self.undone?
        {% end %}
        nodes << Node.new(self, association, index)
        {% begin %}
          {% ancestors = @type.ancestors << @type %}
          {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
          {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
          unless skip_associated
            {% for method in methods %}
              if (%body = {{method.body.last}})
                if %body.responds_to?(:each_with_index)
                  %body.each_with_index do |model, i|
                    unless nodes.any? { |node| model == node.model }
                      if model.responds_to?(:_serialize_graph)
                        model._serialize_graph(nodes, {{method.name[13..-1].stringify}}, i, skip_associated: false)
                      end
                    end
                  end
                else
                  unless nodes.any? { |node| %body == node.model }
                    if %body.responds_to?(:_serialize_graph)
                      %body._serialize_graph(nodes, {{method.name[13..-1].stringify}}, skip_associated: false)
                    end
                  end
                end
              end
            {% end %}
          end
        {% end %}
      end

      private macro with_callbacks(before, after, skip_associated = false, &block)
        %nodes = [] of Node
        # iteratively run lifecycle callbacks, which can add new
        # associated models, which must be processed and added to
        # nodes, in turn
        loop do
          %new = serialize_graph(skip_associated: skip_associated)
          %delta = %new - %nodes
          %nodes = %new
          break if %delta.empty?
          %delta.each do |%node|
            %model = %node.model
            next unless %model == self || %model.changed?
            if %model.responds_to?({{before.symbolize}})
              %model.{{before.id}}
            end
          end
        end
        %nodes.each do |%node|
          %model = %node.model
          next unless %model == self || %model.changed?
          {% (param = block.args.first) || raise "with_callbacks block must have one parameter" %}
          {{param.id}} = %node
          {{block.body}}
          if %model.responds_to?({{after.symbolize}})
            %model.{{after.id}}
          end
        end
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
        with_callbacks(before_validate, after_validate, skip_associated: skip_associated) do |node|
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
        with_callbacks(before_save, after_save, skip_associated: skip_associated) do |node|
          node.model._save_model(skip_validation: skip_validation)
        end
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
          old = @id
          @id = Ktistec.database.exec(
            "INSERT OR REPLACE INTO #{table_name} (#{columns}) VALUES (#{conditions})",
            {% for v in vs %}
              self.{{v}},
            {% end %}
          ).last_insert_id
        {% end %}
        {% begin %}
          {% ancestors = @type.ancestors << @type %}
          {% methods = ancestors.map(&.methods).reduce { |a, b| a + b } %}
          {% methods = methods.select { |d| d.name.starts_with?("_association_") } %}
          # update associated instances
          if @id != old
            {% for method in methods %}
              {% name = method.name[13..-1] %}
              {% if method.body[0] == :has_one && method.body[1] == :id %}
                if (model = {{method.body.last}})
                  model.{{method.body[2].id}} = @id
                  model.update_property({{method.body[2].id.stringify}}, @id) unless model.new_record?
                  model.clear!({{method.body[2]}})
                end
              {% elsif method.body[0] == :has_many && method.body[1] == :id %}
                if (models = {{method.body.last}})
                  models.each do |model|
                    model.{{method.body[2].id}} = @id
                    model.update_property({{method.body[2].id.stringify}}, @id) unless model.new_record?
                    model.clear!({{method.body[2]}})
                  end
                end
              {% end %}
            {% end %}
          end
          # destroy unassociated instances
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

      protected def update_property(property, value)
        raise NilAssertionError.new("#{self.class}: id can't be `nil`") if @id.nil?
        self.class.exec("UPDATE #{table_name} SET #{property} = ? WHERE id = ?", value, @id)
      end

      getter? destroyed = false

      # Destroys the instance.
      #
      def destroy
        self.before_destroy if self.responds_to?(:before_destroy)
        self.class.exec("DELETE FROM #{table_name} WHERE id = ?", @id)
        self.after_destroy if self.responds_to?(:after_destroy)
        @destroyed = true
        @id = nil
        self
      end

      # Reloads the properties from the database.
      #
      # Only reloads the persistent properties. Does not trigger any
      # side effects. Does not ensure that the instance's state is
      # otherwise valid.
      #
      def reload!
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify.stringify).join(",")}}
          Ktistec.database.query_one(
            "SELECT #{columns} FROM #{table_name} WHERE id = ?", id,
          ) do |rs|
            __for_internal_use_only({
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            })
          end
          self
        {% end %}
      rescue DB::NoResultsError
        raise NotFound.new("#{self.class} id=#{id}: not found")
      end

      def new_record?
        @id.nil?
      end

      def changed!(*properties : Symbol)
        properties.each { |property| @changed << property }
      end

      def changed?
        new_record? || !@changed.empty?
      end

      def changed?(*properties : Symbol)
        new_record? || properties.any?(&.in?(@changed))
      end

      def clear!
        @changed.clear
      end

      def clear!(*properties : Symbol)
        @changed -= properties
      end

      protected def clear_saved_record
        @saved_record = nil
        self
      end

      def to_s(io : IO)
        io << "#<"
        self.class.to_s(io)
        io << " id="
        self.id.to_s(io)
        io << ">"
      end

      def inspect(io : IO)
        io << "#<"
        self.class.to_s(io)
        io << ":0x"
        self.object_id.to_s(io, 16)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          {% for v in vs %}
            io << " " << {{v.stringify}} << "="
            self.{{v}}.inspect(io)
          {% end %}
        {% end %}
        io << ">"
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

      # Table name.
      #
      # Overrides the name derived from the class name.
      #
      @@table_name : String?

      # Table columns.
      #
      # Specifies columns that should be retrieved in queries by
      # default that cannot be inferred from annotated instance
      # variables.
      #
      @@table_columns : Array(String)?
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

    class TypeError < Exception
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
