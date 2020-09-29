require "benchmark"

module Ktistec
  # Database utilities.
  #
  module Database
    @@migrations = {} of Version => Definition

    # Returns all defined migrations in no particular order.
    #
    def self.all_migrations
      @@migrations
    end

    # Returns all versions in sorted order.
    #
    def self.all_versions
      @@migrations.keys.sort
    end

    # Returns all applied versions.
    #
    def self.all_applied_versions
      Ktistec.database.query_all("SELECT id FROM migrations", as: Int)
    end

    # Returns all pending versions.
    #
    def self.all_pending_versions
      all_versions - all_applied_versions
    end

    # Finds migration by version.
    #
    def self.find_migration(version)
      @@migrations[version]
    end

    # Perform an operation on a migration.
    #
    def self.do_operation(operation, version)
      migration = find_migration(version)
      case operation
      when :create
        if all_applied_versions.includes?(version)
          "#{migration.name}: is already applied"
        else
          Ktistec.database.exec("INSERT INTO migrations VALUES (?, ?)", version, migration.name)
          "#{migration.name}: created but not applied"
        end
      when :apply
        if all_applied_versions.includes?(version)
          "#{migration.name}: is already applied"
        elsif (up = migration.up).nil?
          "#{migration.name}: is not defined"
        else
          time = Benchmark.measure { up.call(Ktistec.database) }
          Ktistec.database.exec("INSERT INTO migrations VALUES (?, ?)", version, migration.name)
          "#{migration.name}: applied in %.4fs" % time.real
        end
      when :destroy
        if all_pending_versions.includes?(version)
          "#{migration.name}: is already reverted"
        else
          Ktistec.database.exec("DELETE FROM migrations WHERE id = ?", version)
          "#{migration.name}: destroyed but not reverted"
        end
      when :revert
        if all_pending_versions.includes?(version)
          "#{migration.name}: is already reverted"
        elsif (down = migration.down).nil?
          "#{migration.name}: is not defined"
        else
          time = Benchmark.measure { down.call(Ktistec.database) }
          Ktistec.database.exec("DELETE FROM migrations WHERE id = ?", version)
          "#{migration.name}: reverted in %.4fs" % time.real
        end
      else
        raise "invalid operation: #{operation}"
      end
    end

    # Common interface for all migrations.
    #
    module Migration
      # Applies the migration.
      #
      def up(filename = __FILE__, &proc : Operation)
        if filename.split("/").last =~ PATTERN
          Ktistec::Database.all_migrations.tap do |all_migrations|
            all_migrations[$1.to_i] =
              if (definition = all_migrations[$1.to_i]?)
                definition.copy_with(up: proc)
              else
                Definition.new(name: $2, up: proc)
              end
          end
        end
      end

      # Reverts the migration.
      #
      def down(filename = __FILE__, &proc : Operation)
        if filename.split("/").last =~ PATTERN
          Ktistec::Database.all_migrations.tap do |all_migrations|
            all_migrations[$1.to_i] =
              if (definition = all_migrations[$1.to_i]?)
                definition.copy_with(down: proc)
              else
                Definition.new(name: $2, down: proc)
              end
          end
        end
      end

      private PATTERN = /^([0-9]+)-(.+).cr$/
    end

    private alias Version = Int32
    private alias Operation = Proc(DB::Database, Nil)

    private record(
      Definition,
      name : String,
      up : Operation? = nil,
      down : Operation? = nil,
    )
  end
end

require "../database/migrations/**"
