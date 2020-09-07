lib LibXML
  fun xmlAddChild(parent : Node*, child : Node*) : Node*
end

struct XML::Node
  def add_child(child : Node)
    LibXML.xmlUnlinkNode(child)
    LibXML.xmlAddChild(self, child)
    child
  end
end
