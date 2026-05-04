module Slang
  PROCESS_PATH = "#{__DIR__}/process"

  macro embed(filename, io_name)
    \{{ run({{PROCESS_PATH}}, {{filename}}, {{io_name.id.stringify}}) }}
  end
end
