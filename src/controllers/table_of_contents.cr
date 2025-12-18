require "../framework/controller"
require "../models/relationship/content/canonical"
require "../models/activity_pub/object"
require "../views/view_helper"

class TableOfContentsController
  include Ktistec::Controller

  record PathTreeNode, entry : ActivityPub::Object?, children : Hash(String, PathTreeNode)

  def self.build_path_tree(entries : Enumerable(ActivityPub::Object)) : Hash(String, PathTreeNode)
    entries = entries.sort_by(&.canonical_path.not_nil!)
    entries_map = entries.to_h { |object| {object.canonical_path.not_nil!, object} }
    tree = {} of String => PathTreeNode
    entries.each do |object|
      current = tree
      path = object.canonical_path.not_nil!
      segments = path.split('/').reject(&.empty?)
      segments.each_with_index do |segment, index|
        intermediate_path = "/#{segments[0..index].join("/")}"
        intermediate_entry = entries_map[intermediate_path]?
        if index == segments.size - 1
          current[segment] = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        else
          if !current.has_key?(segment)
            current[segment] = PathTreeNode.new(entry: intermediate_entry, children: {} of String => PathTreeNode)
          elsif !current[segment].entry && intermediate_entry
            current[segment] = PathTreeNode.new(entry: intermediate_entry, children: current[segment].children)
          end
          current = current[segment].children
        end
      end
    end
    tree
  end

  def self.render_toc_html(io : IO, tree : Hash(String, PathTreeNode), prefix : String)
    tree.each do |segment, node|
      io << %Q|<div class="item">|
      if (entry = node.entry) && (display_path = entry.canonical_path)
        io << %Q|<a href="#{::HTML.escape(display_path)}">#{::HTML.escape(segment)}</a>|
      else
        io << ::HTML.escape(segment)
      end
      unless node.children.empty?
        io << %Q|<div class="list">|
        render_toc_html(io, node.children, "#{prefix}/#{segment}")
        io << %Q|</div>|
      end
      io << %Q|</div>|
    end
  end

  def self.render_toc_html(tree : Hash(String, PathTreeNode), prefix : String = "") : String
    String.build do |io|
      render_toc_html(io, tree, prefix)
    end
  end

  def self.render_toc_json(json : JSON::Builder, tree : Hash(String, PathTreeNode), prefix : String)
    tree.each do |segment, node|
      json.object do
        json.field("text", segment)
        if (entry = node.entry) && (display_path = entry.canonical_path)
          json.field("path", display_path)
        end
        json.field("children") do
          json.array do
            render_toc_json(json, node.children, "#{prefix}/#{segment}")
          end
        end
      end
    end
  end

  def self.render_toc_json(tree : Hash(String, PathTreeNode), prefix : String = "") : String
    JSON.build do |json|
      json.array do
        render_toc_json(json, tree, prefix)
      end
    end
  end

  get "/.table-of-contents" do |env|
    host = Ktistec.host
    entries = Relationship::Content::Canonical.all.compact_map do |canonical|
      iri = "#{host}#{canonical.to_iri}"
      if (object = ActivityPub::Object.find?(iri)) && (path = object.canonical_path) && object.published
        object
      end
    end
    tree = build_path_tree(entries)
    ok "table_of_contents/index", env: env, tree: tree
  end
end
