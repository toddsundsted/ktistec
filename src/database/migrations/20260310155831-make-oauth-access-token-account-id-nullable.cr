require "../../framework/database"

extend Ktistec::Database::Migration

ACCOUNT_ID_NOT_NULL = /("?)account_id("?)\s+(integer)\s+NOT\s+NULL/i
ACCOUNT_ID_NULLABLE = /("?)account_id("?)\s+(integer)(?!\s+NOT\s+NULL)/i

up do |db|
  table_name = "oauth_access_tokens"
  temp_table = "#{table_name}_new"

  table_sql = db.scalar(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
    table_name
  ).as(String)

  unless table_sql =~ ACCOUNT_ID_NOT_NULL
    raise "Migration failed: could not find 'account_id integer NOT NULL' in schema"
  end

  modified_sql = table_sql
    .gsub(ACCOUNT_ID_NOT_NULL) { |_, m| "#{m[1]}account_id#{m[2]} #{m[3]}" }
    .gsub(table_name, temp_table)

  indexes = [] of String
  db.query(
    "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? AND sql IS NOT NULL",
    table_name
  ) do |rs|
    rs.each do
      indexes << rs.read(String)
    end
  end

  db.exec(modified_sql)

  db.exec("INSERT INTO #{temp_table} SELECT * FROM #{table_name}")

  db.exec("DROP TABLE #{table_name}")

  db.exec("ALTER TABLE #{temp_table} RENAME TO #{table_name}")

  indexes.each do |index_sql|
    db.exec(index_sql)
  end

  final_sql = db.scalar(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
    table_name
  ).as(String)
  unless final_sql =~ ACCOUNT_ID_NULLABLE
    raise "Migration failed: account_id should be nullable"
  end

  db.exec("ANALYZE #{table_name}")
end

down do |db|
  table_name = "oauth_access_tokens"
  temp_table = "#{table_name}_new"

  table_sql = db.scalar(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
    table_name
  ).as(String)

  unless table_sql =~ ACCOUNT_ID_NULLABLE
    raise "Migration failed: could not find nullable 'account_id integer' in schema"
  end

  modified_sql = table_sql
    .gsub(ACCOUNT_ID_NULLABLE) { |_, m| "#{m[1]}account_id#{m[2]} #{m[3]} NOT NULL" }
    .gsub(table_name, temp_table)

  indexes = [] of String
  db.query(
    "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? AND sql IS NOT NULL",
    table_name
  ) do |rs|
    rs.each do
      indexes << rs.read(String)
    end
  end

  db.exec(modified_sql)

  db.exec("INSERT INTO #{temp_table} SELECT * FROM #{table_name} WHERE account_id IS NOT NULL")

  db.exec("DROP TABLE #{table_name}")

  db.exec("ALTER TABLE #{temp_table} RENAME TO #{table_name}")

  indexes.each do |index_sql|
    db.exec(index_sql)
  end

  final_sql = db.scalar(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
    table_name
  ).as(String)
  unless final_sql =~ ACCOUNT_ID_NOT_NULL
    raise "Migration failed: account_id should be NOT NULL"
  end

  db.exec("ANALYZE #{table_name}")
end
