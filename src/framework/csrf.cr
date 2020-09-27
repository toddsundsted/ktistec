require "kemal-session"
require "kemal-csrf"

add_handler CSRF.new(
  allowed_routes: ["/actors/:username/inbox"]
)
