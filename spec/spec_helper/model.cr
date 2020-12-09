require "./base"

require "../../src/framework/database"
require "../../src/framework/ext/sqlite3"

Ktistec::Database.all_pending_versions.each do |version|
  puts Ktistec::Database.do_operation(:apply, version)
end
