module Balloon
  module Model
    # Marks properties as persistent.
    #
    annotation Persistent
    end

    # Model utilities.
    #
    module Utils
      # Returns the table name, given a model.
      #
      def self.table_name(clazz)
        (name = clazz.to_s.underscore) +
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
        @@table_name ||= Utils.table_name({{@type}})
      end

      # Returns the count of saved instances.
      #
      def count
        Balloon.database.scalar("SELECT COUNT(*) FROM #{table_name}").as(Int)
      end

      # Returns all instances.
      #
      def all
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify)}}.join(",")
          Balloon.database.query_all(
            "SELECT #{columns} FROM #{table_name}"
          ) do |rs|
            {{@type}}.new(
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            )
          end
        {% end %}
      end

      # Finds the saved instance.
      #
      def find(id)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify)}}.join(",")
          conditions = "id = ?"
          Balloon.database.query_one(
            "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            id.not_nil!
          ) do |rs|
            {{@type}}.new(
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            )
          end
        {% end %}
      end

      # Finds the saved instance.
      #
      def find(**options)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify)}}.join(",")
          conditions = {{vs.map(&.stringify)}}.select do |v|
            options.has_key?(v)
          end.map do |v|
            "#{v} = ?"
          end.join(",")
          Balloon.database.query_one(
            "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            *options.values
          ) do |rs|
            {{@type}}.new(
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            )
          end
        {% end %}
      end

      # Returns saved instances.
      #
      def where(**options)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify)}}.join(",")
          conditions = {{vs.map(&.stringify)}}.select do |v|
            options.has_key?(v)
          end.map do |v|
            "#{v} = ?"
          end.join(",")
          Balloon.database.query_all(
            "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            *options.values
          ) do |rs|
            {{@type}}.new(
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            )
          end
        {% end %}
      end

      # Returns saved instances.
      #
      def where(conditions : String, *arguments)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          columns = {{vs.map(&.stringify)}}.join(",")
          Balloon.database.query_all(
            "SELECT #{columns} FROM #{table_name} WHERE #{conditions}",
            *arguments
          ) do |rs|
            {{@type}}.new(
              {% for v in vs %}
                {{v}}: rs.read({{v.type}}),
              {% end %}
            )
          end
        {% end %}
      end
    end

    module InstanceMethods
      # Initializes the new instance.
      #
      def initialize(**options)
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
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
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
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
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
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
        @@table_name ||= Utils.table_name({{@type}})
      end

      # Saves the instance.
      #
      def save
        {% begin %}
          {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
          if @id
            conditions = {{vs.map(&.stringify)}}.map do |v|
              "#{v} = ?"
            end.join(",")
            Balloon.database.exec(
              "UPDATE #{table_name} SET #{conditions} WHERE id = ?",
              {% for v in vs %}
                {{v}},
              {% end %}
              @id
            )
          else
            columns = {{vs.map(&.stringify)}}.join(",")
            conditions = (["?"] * {{vs.size}}).join(",")
            @id = Balloon.database.exec(
              "INSERT INTO #{table_name} (#{columns}) VALUES (#{conditions})",
              {% for v in vs %}
                {{v}},
              {% end %}
            ).last_insert_id
          end
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
    end

    macro included
      extend ClassMethods
      include InstanceMethods
    end

    @[Persistent]
    property id : Int64?

    @@table_name : String?
  end
end

require "../models/**"
