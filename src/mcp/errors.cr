class MCPError < Exception
  getter code : Int32

  def initialize(@message : String, @code : Int32)
    super(@message)
  end
end
