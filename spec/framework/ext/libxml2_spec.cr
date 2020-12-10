require "spectator"

require "../../../src/framework/ext/libxml2"

Spectator.describe "LibXML2 extensions" do
  let(parent) { XML.parse("<parent/>").first_element_child.not_nil! }
  let(child) { XML.parse("<child/>").first_element_child.not_nil! }

  it "adds a child" do
    parent.add_child(child)
    expect(parent.xpath_node("/parent/child")).to eq(child)
  end
end
