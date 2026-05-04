# Slang AST.
#
module Slang
  module AST
    # 1-based source location
    record SourceLoc, line : Int32, column : Int32

    # `name=value` attribute on an element. the value is a Crystal expression
    record Attribute, name : String, value : String, loc : SourceLoc

    # `*expr` splat on an element. the expression must evaluate to a hash
    record Splat, expr : String, loc : SourceLoc

    abstract class TextPart
      getter loc : SourceLoc

      def initialize(@loc : SourceLoc)
      end
    end

    class Literal < TextPart
      getter value : String
      getter escape : Bool

      def initialize(@value : String, @escape : Bool, loc : SourceLoc)
        super(loc)
      end
    end

    class Interp < TextPart
      getter expr : String
      getter escape : Bool

      def initialize(@expr : String, @escape : Bool, loc : SourceLoc)
        super(loc)
      end
    end

    abstract class Node
      getter loc : SourceLoc

      def initialize(@loc : SourceLoc)
      end
    end

    class Document < Node
      getter nodes : Array(Node)

      def initialize(loc : SourceLoc)
        super(loc)
        @nodes = [] of Node
      end
    end

    # abstract parent for the three node types that can host an
    # indented block following an inline-element chain: `Element`,
    # `Output`, `Code`.

    abstract class IndentHost < Node
      getter children : Array(Node)

      def initialize(loc : SourceLoc)
        super(loc)
        @children = [] of Node
      end
    end

    class Element < IndentHost
      getter tag : String
      getter classes : Array(String)
      property id : String?
      getter attrs : Array(Attribute)
      getter splats : Array(Splat)
      property ws_left : Bool
      property ws_right : Bool

      def initialize(@tag : String, loc : SourceLoc)
        super(loc)
        @classes = [] of String
        @id = nil
        @attrs = [] of Attribute
        @splats = [] of Splat
        @ws_left = false
        @ws_right = false
      end
    end

    # element trailing text wrapped as a child node

    class Text < Node
      getter parts : Array(TextPart)

      def initialize(loc : SourceLoc)
        super(loc)
        @parts = [] of TextPart
      end
    end

    class Output < IndentHost
      getter expr : String
      getter escape : Bool
      property ws_left : Bool
      property ws_right : Bool

      def initialize(@expr : String, @escape : Bool, loc : SourceLoc)
        super(loc)
        @ws_left = false
        @ws_right = false
      end
    end

    enum BranchableKind
      If
      Case
      Begin
    end

    enum BranchKind
      Else
      Elsif
      When
      In
      Rescue
      Ensure
    end

    class Code < IndentHost
      getter expr : String
      getter branchable : BranchableKind?
      getter branch : BranchKind?
      getter branches : Array(Code)

      def initialize(@expr : String,
                     @branchable : BranchableKind?,
                     @branch : BranchKind?,
                     loc : SourceLoc)
        super(loc)
        @branches = [] of Code
      end
    end

    enum TextBlockKind
      Pipe
      Quote
    end

    # multi-line verbatim text

    class TextBlock < Node
      getter kind : TextBlockKind
      getter parts : Array(TextPart)

      def initialize(@kind : TextBlockKind, loc : SourceLoc)
        super(loc)
        @parts = [] of TextPart
      end
    end

    class RawHtml < Node
      getter parts : Array(TextPart)

      def initialize(loc : SourceLoc)
        super(loc)
        @parts = [] of TextPart
      end
    end

    class HiddenComment < Node
      getter children : Array(Node)

      def initialize(loc : SourceLoc)
        super(loc)
        @children = [] of Node
      end
    end

    class VisibleComment < Node
      getter parts : Array(TextPart)
      getter children : Array(Node)

      def initialize(loc : SourceLoc)
        super(loc)
        @parts = [] of TextPart
        @children = [] of Node
      end
    end

    class ConditionalComment < Node
      getter condition : String
      getter children : Array(Node)

      def initialize(@condition : String, loc : SourceLoc)
        super(loc)
        @children = [] of Node
      end
    end

    class Doctype < Node
      getter value : String

      def initialize(@value : String, loc : SourceLoc)
        super(loc)
      end
    end

    enum RawstuffFlavor
      JavaScript # `javascript:` -> `<script>` wrapper
      CSS        # `css:` -> `<style>` wrapper
      Crystal    # `crystal:` -> verbatim embedded Crystal source
    end

    class Rawstuff < Node
      getter flavor : RawstuffFlavor
      getter parts : Array(TextPart)

      def initialize(@flavor : RawstuffFlavor, loc : SourceLoc)
        super(loc)
        @parts = [] of TextPart
      end
    end
  end
end
