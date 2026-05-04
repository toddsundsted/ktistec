# Crystal-aware byte scanner for finding the end of a Crystal
# expression embedded in Slang source.
#
# The scanner does not parse Crystal -- it tracks bracket nesting and
# string/char/percent-literal/comment state so the caller can locate a
# depth-zero terminator. The Crystal compiler validates the resulting
# expression later.
#
# Used by the Slang lexer at every site that switches into
# Crystal-expression mode.
#
module Slang::CrystalScanner
  extend self

  # Scans `source` starting at byte index `pos`.
  #
  # Returns the byte index of the first depth-zero occurrence of any
  # byte in `terminators`, or `source.bytesize` if no terminator is
  # found.
  #
  # "Depth zero" means: not inside any string literal, char literal,
  # percent literal, line comment, or bracket nesting.
  #
  # The returned position points at the terminator byte (the byte is
  # not consumed).
  #
  # `terminators` must be ASCII. Newline bytes (0x0A) terminate only
  # if included in `terminators`.
  #
  def scan(source : String, pos : Int32, terminators : String) : Int32
    bytes = source.to_slice
    terminator_bytes = terminators.to_slice
    validate_ascii_terminators(terminator_bytes)
    pos = 0 if pos < 0
    pos = bytes.size if pos > bytes.size
    scan_bytes(bytes, pos, terminator_bytes)
  end

  private INTERP_TERMINATOR = Bytes['}'.ord.to_u8]

  private def validate_ascii_terminators(terminators : Bytes) : Nil
    terminators.each do |byte|
      if byte >= 0x80
        raise ArgumentError.new("terminators must be ASCII")
      end
    end
  end

  private def scan_bytes(bytes : Bytes, pos : Int32, terminators : Bytes) : Int32
    size = bytes.size
    depth = 0

    while pos < size
      byte = bytes[pos]

      if depth == 0 && terminators.includes?(byte)
        return pos
      end

      case byte
      when '('.ord.to_u8, '['.ord.to_u8, '{'.ord.to_u8
        depth += 1
        pos += 1
      when ')'.ord.to_u8, ']'.ord.to_u8, '}'.ord.to_u8
        depth -= 1 if depth > 0
        pos += 1
      when '"'.ord.to_u8
        pos = scan_double_string(bytes, pos + 1)
      when '\''.ord.to_u8
        pos = scan_char_literal(bytes, pos + 1)
      when '%'.ord.to_u8
        pos = scan_percent(bytes, pos)
      when '#'.ord.to_u8
        pos = scan_line_comment(bytes, pos)
      else
        pos += 1
      end
    end

    pos
  end

  private def scan_double_string(bytes : Bytes, pos : Int32) : Int32
    size = bytes.size
    while pos < size
      byte = bytes[pos]
      case byte
      when '\\'.ord.to_u8
        pos += 2
      when '#'.ord.to_u8
        if pos + 1 < size && bytes[pos + 1] == '{'.ord.to_u8
          pos = scan_bytes(bytes, pos + 2, INTERP_TERMINATOR)
          pos += 1 if pos < size
        else
          pos += 1
        end
      when '"'.ord.to_u8
        return pos + 1
      else
        pos += 1
      end
    end
    size
  end

  private def scan_char_literal(bytes : Bytes, pos : Int32) : Int32
    size = bytes.size
    while pos < size
      byte = bytes[pos]
      case byte
      when '\\'.ord.to_u8
        pos += 2
      when '\''.ord.to_u8
        return pos + 1
      else
        pos += 1
      end
    end
    size
  end

  private def scan_percent(bytes : Bytes, pos : Int32) : Int32
    size = bytes.size
    after = pos + 1
    return after if after >= size

    if percent_type_letter?(bytes[after])
      after += 1
    end

    return pos + 1 if after >= size

    opener = bytes[after]
    closer = paired_closer(opener)
    return pos + 1 unless closer

    inner = after + 1

    if opener == closer
      # non-nesting delimiter (`||` form). scan to the next unescaped
      # closer; nested pipes do not stack
      while inner < size
        byte = bytes[inner]
        if byte == '\\'.ord.to_u8
          inner += 2
        elsif byte == '#'.ord.to_u8 && inner + 1 < size && bytes[inner + 1] == '{'.ord.to_u8
          inner = scan_bytes(bytes, inner + 2, INTERP_TERMINATOR)
          inner += 1 if inner < size
        elsif byte == closer
          return inner + 1
        else
          inner += 1
        end
      end
      return inner
    end

    depth = 1
    while inner < size && depth > 0
      byte = bytes[inner]
      if byte == '\\'.ord.to_u8
        inner += 2
      elsif byte == '#'.ord.to_u8 && inner + 1 < size && bytes[inner + 1] == '{'.ord.to_u8
        inner = scan_bytes(bytes, inner + 2, INTERP_TERMINATOR)
        inner += 1 if inner < size
      else
        if byte == opener
          depth += 1
        elsif byte == closer
          depth -= 1
        end
        inner += 1
      end
    end
    inner
  end

  private def scan_line_comment(bytes : Bytes, pos : Int32) : Int32
    size = bytes.size
    while pos < size && bytes[pos] != '\n'.ord.to_u8
      pos += 1
    end
    pos
  end

  private def percent_type_letter?(byte : UInt8) : Bool
    case byte
    when 'w'.ord.to_u8,
         'i'.ord.to_u8,
         'q'.ord.to_u8, 'Q'.ord.to_u8,
         'r'.ord.to_u8, 'x'.ord.to_u8
      true
    else
      false
    end
  end

  private def paired_closer(opener : UInt8) : UInt8?
    case opener
    when '('.ord.to_u8 then ')'.ord.to_u8
    when '['.ord.to_u8 then ']'.ord.to_u8
    when '{'.ord.to_u8 then '}'.ord.to_u8
    when '<'.ord.to_u8 then '>'.ord.to_u8
    when '|'.ord.to_u8 then '|'.ord.to_u8
    end
  end
end
