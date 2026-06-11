require "ameba"
require "ecr/processor"

require "../src/slang"

require "../src/ameba/ktistec/no_direct_factory_calls"
require "../src/ameba/ktistec/no_imperative_factories"
require "../src/ameba/ktistec/no_redundant_factory_name"
require "../src/ameba/ktistec/no_alternatives_in_specs"
require "../src/ameba/ktistec/no_eq_boolean_in_specs"
require "../src/ameba/ktistec/no_else_nil"
require "../src/ameba/ktistec/no_explicit_return_nil"
require "../src/ameba/ktistec/no_focused_specs"
require "../src/ameba/ktistec/no_pending_specs"
require "../src/ameba/ktistec/trailing_comma_on_stacked"
require "../src/ameba/ktistec/assert_safe_whitelist"

# Slang and ECR templates compile to Crystal at build time. Ameba
# normally only scans `.cr` files. These monkey-patches bridge that:
#
# 1. `Config#sources` is extended to additionally include every .slang
#    file under `src/views/` (processed through `Slang.process_string`)
#    and every .ecr file under `src/views/` (processed through
#    `ECR.process_string`).
#
# 2. `Rule::Base#excluded?` is extended so that rules opt in to
#    running on template-derived sources. Only rules that override
#    `template_aware?` to return `true` see them.
#
# 3. `Formatter::Util#affected_code` is extended so that, when an
#    issue's location filename ends in `.slang` or `.ecr`, the
#    diagnostic snippet is read from the original template file
#    rather than from the generated-Crystal `Source#code`.

module Ameba
  class Config
    SLANG_GLOBS = ["src/views/**/*.slang"]
    ECR_GLOBS   = ["src/views/**/*.ecr"]

    def sources
      base = previous_def
      SLANG_GLOBS.each do |glob|
        Dir.glob(glob) { |path| inject_template_source(base, path) { ::Slang.process_string(File.read(path), path) } }
      end
      ECR_GLOBS.each do |glob|
        Dir.glob(glob) { |path| inject_template_source(base, path) { ::ECR.process_string(File.read(path), path) } }
      end
      base
    end

    private def inject_template_source(base, path, &)
      generated_code = yield
      source = Source.new(generated_code, path)
      source.ast
      base << source
    rescue ex
      STDERR.puts "skipping #{path}: #{ex.class}: #{ex.message}"
    end
  end

  abstract class Rule::Base
    def excluded?(source)
      if (source.path.ends_with?(".slang") || source.path.ends_with?(".ecr")) && !template_aware?
        return true
      end
      previous_def
    end

    # Rules that should run on template-derived sources (.slang, .ecr)
    # override this to return `true`. Default `false`.
    #
    def template_aware? : Bool
      false
    end
  end
end

# Built-in rules audited as safe to run on template-derived sources.

class Ameba::Rule::Performance::ChainedCallWithNoBang
  def template_aware? : Bool
    true
  end
end

class Ameba::Rule::Performance::CompactAfterMap
  def template_aware? : Bool
    true
  end
end

class Ameba::Rule::Naming::BlockParameterName
  def template_aware? : Bool
    true
  end
end

class Ameba::Rule::Style::VerboseBlock
  def template_aware? : Bool
    true
  end
end

module Ameba::Formatter::Util
  def affected_code(issue : ::Ameba::Issue, context_lines = 0, max_length = 120, ellipsis = " ...", prompt = "> ")
    return unless location = issue.location
    filename = location.filename.as?(String)
    code =
      if filename && (filename.ends_with?(".slang") || filename.ends_with?(".ecr")) && File.exists?(filename)
        File.read(filename)
      else
        issue.code
      end
    affected_code(code, location, issue.end_location, context_lines, max_length, ellipsis, prompt)
  end
end

require "ameba/cli"
