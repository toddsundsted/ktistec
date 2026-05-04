require "spectator"
require "spectator/should"

require "../../src/slang"

macro render_string(slang)
  String.build do |__str__|
    \{{ run("./support/process", {{slang}}, "__str__") }}
  end
end

def evaluates_to_true
  true
end

def evaluates_to_false
  false
end

def evaluates_to_hello
  "hello"
end

# Side-effect counter.
#
class Counter
  property count : Int32 = 0

  def call(value)
    @count += 1
    value
  end
end
