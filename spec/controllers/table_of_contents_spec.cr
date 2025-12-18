require "../../src/controllers/table_of_contents"
require "../../src/controllers/objects"

require "../spec_helper/controller"
require "../spec_helper/factory"

Spectator.describe TableOfContentsController do
  setup_spec

  let(actor) { register.actor }

  let(published) { Time.utc(2025, 1, 1, 12, 0, 0) }

  macro publish_object(named, canonical_path)
    let_create!(
      :object, named: {{named.id}},
      attributed_to: actor,
      canonical_path: {{canonical_path}},
      published: published,
      local: true,
    )
  end

  describe ".build_path_tree" do
    it "returns empty tree" do
      result = described_class.build_path_tree([] of ActivityPub::Object)

      expect(result).to be_empty
    end

    context "with a single entry" do
      publish_object(:object, "/single")

      it "creates a single node" do
        tree = described_class.build_path_tree([object])

        expect(tree.keys).to contain_exactly("single")
        node = tree["single"]
        expect(node.entry).to eq(object)
        expect(node.children).to be_empty
      end
    end

    context "with multiple entries" do
      publish_object(:object1, "/alpha")
      publish_object(:object2, "/beta")

      it "creates multiple nodes" do
        tree = described_class.build_path_tree([object1, object2])

        expect(tree.keys).to contain_exactly("alpha", "beta")
        expect(tree["alpha"].entry).to eq(object1)
        expect(tree["beta"].entry).to eq(object2)
      end
    end

    context "with nested paths" do
      publish_object(:parent, "/parent")
      publish_object(:child, "/parent/child")

      it "creates nested tree" do
        tree = described_class.build_path_tree([parent, child])

        expect(tree.keys).to contain_exactly("parent")
        parent_node = tree["parent"]
        expect(parent_node.entry).to eq(parent)
        expect(parent_node.children.keys).to contain_exactly("child")
        child_node = parent_node.children["child"]
        expect(child_node.entry).to eq(child)
        expect(child_node.children).to be_empty
      end

      it "creates nested tree" do
        tree = described_class.build_path_tree([child, parent])  # reverse order

        expect(tree.keys).to contain_exactly("parent")
        parent_node = tree["parent"]
        expect(parent_node.entry).to eq(parent)
        expect(parent_node.children.keys).to contain_exactly("child")
        child_node = parent_node.children["child"]
        expect(child_node.entry).to eq(child)
        expect(child_node.children).to be_empty
      end
    end

    context "with intermediate path" do
      publish_object(:child, "/parent/child")

      it "creates intermediate node without entry" do
        tree = described_class.build_path_tree([child])

        expect(tree.keys).to contain_exactly("parent")
        parent_node = tree["parent"]
        expect(parent_node.entry).to be_nil
        expect(parent_node.children.keys).to contain_exactly("child")
        child_node = parent_node.children["child"]
        expect(child_node.entry).to eq(child)
        expect(child_node.children).to be_empty
      end
    end

    context "with deeply nested structures" do
      publish_object(:top, "/deep/level1")
      publish_object(:middle, "/deep/level1/level2")
      publish_object(:bottom, "/deep/level1/level2/level3")

      it "handles deeply nested structures" do
        tree = described_class.build_path_tree([top, middle, bottom])

        deep_node = tree["deep"]
        expect(deep_node.entry).to be_nil
        level1_node = deep_node.children["level1"]
        expect(level1_node.entry).to eq(top)
        level2_node = level1_node.children["level2"]
        expect(level2_node.entry).to eq(middle)
        level3_node = level2_node.children["level3"]
        expect(level3_node.entry).to eq(bottom)
      end
    end

    context "with multiple branches from the same parent" do
      publish_object(:parent, "/multi")
      publish_object(:branch1, "/multi/branch1")
      publish_object(:branch2, "/multi/branch2")

      it "handles multiple branches" do
        tree = described_class.build_path_tree([parent, branch1, branch2])

        multi_node = tree["multi"]
        expect(multi_node.entry).to eq(parent)
        expect(multi_node.children.keys).to contain_exactly("branch1", "branch2")
        expect(multi_node.children["branch1"].entry).to eq(branch1)
        expect(multi_node.children["branch2"].entry).to eq(branch2)
      end
    end
  end

  alias PathTreeNode = TableOfContentsController::PathTreeNode

  describe ".render_toc_html" do
    it "returns empty string" do
      result = described_class.render_toc_html({} of String => PathTreeNode)

      expect(result).to eq("")
    end

    it "renders a single node without entry" do
      node = PathTreeNode.new(entry: nil, children: {} of String => PathTreeNode)
      tree = {"segment" => node}
      result = described_class.render_toc_html(tree)

      expect(result).to eq(%Q|<div class="item">segment</div>|)
    end

    context "with a single node with entry" do
      publish_object(:object, "/test-html-1")

      it "renders the node" do
        node = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        tree = {"test-html-1" => node}
        result = described_class.render_toc_html(tree)

        expect(result).to eq(%Q|<div class="item"><a href="/test-html-1">test-html-1</a></div>|)
      end
    end

    context "with prefix" do
      publish_object(:object, "/test-html-2/bar")

      it "strips prefix from displayed path" do
        node = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        tree = {"bar" => node}
        result = described_class.render_toc_html(tree, "/test-html-2")

        expect(result).to eq(%Q|<div class="item"><a href="/test-html-2/bar">bar</a></div>|)
      end
    end

    context "with nested children" do
      publish_object(:parent, "/test-html-3/bar")
      publish_object(:child, "/test-html-3/bar/baz")

      it "renders nested children" do
        child_node = PathTreeNode.new(entry: child, children: {} of String => PathTreeNode)
        parent_node = PathTreeNode.new(entry: parent, children: {"baz" => child_node})
        tree = {"bar" => parent_node}
        result = described_class.render_toc_html(tree, "/test-html-3")

        expect(result).to eq(
          %Q|<div class="item"><a href="/test-html-3/bar">bar</a><div class="list"><div class="item"><a href="/test-html-3/bar/baz">baz</a></div></div></div>|
        )
      end
    end

    context "when parent has no entry" do
      publish_object(:child, "/test-html-4/bar/baz")

      it "renders nested children" do
        child_node = PathTreeNode.new(entry: child, children: {} of String => PathTreeNode)
        parent_node = PathTreeNode.new(entry: nil, children: {"baz" => child_node})
        tree = {"bar" => parent_node}
        result = described_class.render_toc_html(tree, "/test-html-4")

        expect(result).to eq(
          %Q|<div class="item">bar<div class="list"><div class="item"><a href="/test-html-4/bar/baz">baz</a></div></div></div>|,
        )
      end
    end

    context "with HTML in path" do
      publish_object(:object, "/test-html-5/<script>alert('xss')</script>")

      it "escapes HTML" do
        node = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        tree = {"<script>alert('xss')</script>" => node}
        result = described_class.render_toc_html(tree, "/test-html-5")

        expect(result).to eq(
          %Q|<div class="item"><a href="/test-html-5/&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;">&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</a></div>|,
        )
      end
    end
  end

  describe ".render_toc_json" do
    it "returns empty array" do
      result = described_class.render_toc_json({} of String => PathTreeNode)

      expect(result).to eq("[]")
    end

    it "renders a single node without entry" do
      node = PathTreeNode.new(entry: nil, children: {} of String => PathTreeNode)
      tree = {"segment" => node}
      result = described_class.render_toc_json(tree)

      expect(result).to eq(%Q|[{"text":"segment","children":[]}]|)
    end

    context "with a single node with entry" do
      publish_object(:object, "/test-json-1")

      it "renders the node" do
        node = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        tree = {"test-json-1" => node}
        result = described_class.render_toc_json(tree)

        expect(result).to eq(%Q|[{"text":"test-json-1","path":"/test-json-1","children":[]}]|)
      end
    end

    context "with prefix" do
      publish_object(:object, "/test-json-2/bar")

      it "strips prefix from displayed path" do
        node = PathTreeNode.new(entry: object, children: {} of String => PathTreeNode)
        tree = {"bar" => node}
        result = described_class.render_toc_json(tree, "/test-json-2")

        expect(result).to eq(%Q|[{"text":"bar","path":"/test-json-2/bar","children":[]}]|)
      end
    end

    context "with nested children" do
      publish_object(:parent, "/test-json-3/bar")
      publish_object(:child, "/test-json-3/bar/baz")

      it "renders nested children" do
        child_node = PathTreeNode.new(entry: child, children: {} of String => PathTreeNode)
        parent_node = PathTreeNode.new(entry: parent, children: {"baz" => child_node})
        tree = {"bar" => parent_node}
        result = described_class.render_toc_json(tree, "/test-json-3")

        expect(result).to eq(
          %Q|[{"text":"bar","path":"/test-json-3/bar","children":[{"text":"baz","path":"/test-json-3/bar/baz","children":[]}]}]|,
        )
      end
    end

    context "when parent has no entry" do
      publish_object(:child, "/test-json-4/bar/baz")

      it "renders nested children" do
        child_node = PathTreeNode.new(entry: child, children: {} of String => PathTreeNode)
        parent_node = PathTreeNode.new(entry: nil, children: {"baz" => child_node})
        tree = {"bar" => parent_node}
        result = described_class.render_toc_json(tree, "/test-json-4")

        expect(result).to eq(
          %Q|[{"text":"bar","children":[{"text":"baz","path":"/test-json-4/bar/baz","children":[]}]}]|,
        )
      end
    end
  end

  HTML_HEADERS = HTTP::Headers{"Accept" => "text/html"}
  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json"}

  describe "GET /.table-of-contents" do
    it "returns 401 if not authorized" do
      get "/.table-of-contents", HTML_HEADERS

      expect(response.status_code).to eq(401)
    end

    it "return 401 if not authorized" do
      get "/.table-of-contents", JSON_HEADERS

      expect(response.status_code).to eq(401)
    end

    context "when authorized" do
      sign_in(as: actor.username)

      it "is successful" do
        get "/.table-of-contents", HTML_HEADERS

        expect(response.status_code).to eq(200)
      end

      it "is successful" do
        get "/.table-of-contents", JSON_HEADERS

        expect(response.status_code).to eq(200)
      end

      context "with objects having canonical paths" do
        publish_object(:object1, "/alpha")
        publish_object(:object2, "/beta")
        publish_object(:object3, "/gamma")
        let_create!(
          :object, named: :draft,
          attributed_to: actor,
          canonical_path: "/zeta",
          local: true,
        )

        it "includes objects with canonical paths" do
          get "/.table-of-contents", HTML_HEADERS

          expect(response.status_code).to eq(200)
          expect(response.body).to contain(%Q|<a href="/alpha">alpha</a>|)
          expect(response.body).to contain(%Q|<a href="/beta">beta</a>|)
          expect(response.body).to contain(%Q|<a href="/gamma">gamma</a>|)
        end

        it "includes objects with canonical paths" do
          get "/.table-of-contents", JSON_HEADERS

          expect(response.status_code).to eq(200)
          expect(response.body).to contain(%Q|{"text":"alpha","path":"/alpha","children":[]}|)
          expect(response.body).to contain(%Q|{"text":"beta","path":"/beta","children":[]}|)
          expect(response.body).to contain(%Q|{"text":"gamma","path":"/gamma","children":[]}|)
        end

        it "excludes draft objects" do
          get "/.table-of-contents", HTML_HEADERS

          expect(response.status_code).to eq(200)
          expect(response.body).not_to contain(%Q|<a href="/zeta">zeta</a>|)
        end

        it "excludes draft objects" do
          get "/.table-of-contents", JSON_HEADERS

          expect(response.status_code).to eq(200)
          expect(response.body).not_to contain(%Q|{"text":"zeta","path":"/zeta","children":[]}|)
        end
      end
    end
  end
end
