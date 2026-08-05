require "kemal"

# Registers one route handler under more than one path.
#
#     post "/inbox", "/actors/:username/inbox" do |env|
#       ...
#     end
#
{% for method in %w(get post put patch delete options) %}
  def {{method.id}}(path : String, *paths : String, &block : HTTP::Server::Context -> _)
    {{method.id}}(path, &block)
    paths.each do |path|
      {{method.id}}(path, &block)
    end
  end
{% end %}
