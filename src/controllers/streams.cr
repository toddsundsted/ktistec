require "../framework/controller"

class StreamsController
  include Ktistec::Controller

  {% for action in %w(append prepend replace update remove before after morph refresh) %}
    def self.stream_{{action.id}}(io, body, id = nil, selector = nil)
      stream_action(io, body, {{action}}, id, selector)
    end
  {% end %}

  def self.stream_action(io : IO, body : String, action : String, id : String?, selector : String?)
    if id && !selector
      io.puts %Q|data: <turbo-stream action="#{action}" target="#{id}">|
    elsif selector && !id
      io.puts %Q|data: <turbo-stream action="#{action}" targets="#{selector}">|
    else
      raise "one of `id` or `selector` must be provided"
    end
    io.puts "data: <template>"
    body.each_line do |line|
      io.puts "data: #{line}"
    end
    io.puts "data: </template>"
    io.puts "data: </turbo-stream>"
    io.puts
    io.flush
  end
end
