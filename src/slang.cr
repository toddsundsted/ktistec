require "./slang/crystal_scanner"
require "./slang/lexer"
require "./slang/ast"
require "./slang/parser"
require "./slang/code_gen"
require "./slang/runtime"
require "./slang/macros"

module Slang
  DEFAULT_BUFFER_NAME = "__slang__"

  # Reads `.slang` source from `filename`, parses, and returns the
  # equivalent Crystal source as a string. Pure -- no side effects.
  #
  def self.process_file(filename : String, buffer_name : String = DEFAULT_BUFFER_NAME) : String
    process_string(File.read(filename), filename, buffer_name)
  end

  # Same as `process_file` but takes the source as a string. The
  # `filename` argument is used only for source-location directives.
  #
  def self.process_string(source : String, filename : String? = nil, buffer_name : String = DEFAULT_BUFFER_NAME) : String
    document = Parser.parse(source)
    CodeGen.generate(document, filename, buffer_name)
  end
end
