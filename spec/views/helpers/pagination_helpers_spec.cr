require "./support_spec"

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  let(collection) { Ktistec::Util::PaginatedArray(ViewHelperSpecSupport::Model).new }

  PARSER_OPTIONS =
    XML::HTMLParserOptions::NOIMPLIED |
      XML::HTMLParserOptions::NODEFDTD

  describe "paginate" do
    let(query) { "" }

    let(env) { make_env("GET", "/#{query}") }

    subject do
      begin
        body = String.build { |io| self.class.paginate(env, collection, io) }
        XML.parse_html(body, PARSER_OPTIONS).document
      rescue XML::Error
        XML.parse_html("<div/>", PARSER_OPTIONS).document
      end
    end

    it "does not render pagination controls" do
      expect(subject.xpath_nodes("/nav[contains(@class,'pagination')]")).to be_empty
    end

    context "with cursor pagination" do
      before_each do
        collection.cursor_start = 100_i64
        collection.cursor_end = 50_i64
      end

      it "does not render the prev link" do
        expect(subject.xpath_nodes("//a/@href")).not_to contain("?min_id=100")
      end

      it "does not render the next link" do
        expect(subject.xpath_nodes("//a/@href")).not_to contain("?max_id=50")
      end

      context "with prev results" do
        before_each { collection.has_prev = true }

        it "renders the prev link" do
          expect(subject.xpath_nodes("//a/@href")).to contain("?min_id=100")
        end
      end

      context "with next results" do
        before_each { collection.has_next = true }

        it "renders the next link" do
          expect(subject.xpath_nodes("//a/@href")).to contain("?max_id=50")
        end
      end
    end
  end

  describe "cursor_pagination_params" do
    it "defaults to nil" do
      env = make_env("GET", "/")
      result = self.class.cursor_pagination_params(env)
      expect(result[:max_id]).to be_nil
      expect(result[:min_id]).to be_nil
    end

    it "parses max_id" do
      env = make_env("GET", "/?max_id=12345")
      result = self.class.cursor_pagination_params(env)
      expect(result[:max_id]).to eq(12345_i64)
    end

    it "parses min_id" do
      env = make_env("GET", "/?min_id=11111")
      result = self.class.cursor_pagination_params(env)
      expect(result[:min_id]).to eq(11111_i64)
    end

    it "parses limit" do
      env = make_env("GET", "/?limit=20")
      result = self.class.cursor_pagination_params(env)
      expect(result[:limit]).to eq(20)
    end

    it "ensures limit is at least 1" do
      env = make_env("GET", "/?limit=0")
      result = self.class.cursor_pagination_params(env)
      expect(result[:limit]).to eq(1)
    end

    it "ignores negative limit" do
      env = make_env("GET", "/?limit=-5")
      result = self.class.cursor_pagination_params(env)
      expect(result[:limit]).to eq(1)
    end

    it "defaults limit to 10" do
      env = make_env("GET", "/")
      result = self.class.cursor_pagination_params(env)
      expect(result[:limit]).to eq(10)
    end

    context "when user is not authenticated" do
      it "allows limit up to 20" do
        env = make_env("GET", "/?limit=20")
        result = self.class.cursor_pagination_params(env)
        expect(result[:limit]).to eq(20)
      end

      it "limits limit to 20" do
        env = make_env("GET", "/?limit=50")
        result = self.class.cursor_pagination_params(env)
        expect(result[:limit]).to eq(20)
      end
    end

    context "when user is authenticated" do
      sign_in

      it "allows limit up to 1000" do
        env = make_env("GET", "/?limit=1000")
        result = self.class.cursor_pagination_params(env)
        expect(result[:limit]).to eq(1000)
      end

      it "limits limit to 1000" do
        env = make_env("GET", "/?limit=1001")
        result = self.class.cursor_pagination_params(env)
        expect(result[:limit]).to eq(1000)
      end
    end
  end

  describe "cursor_paginate_with_pins" do
    let_create(:actor)
    let_create(:object, named: pinned_object, attributed_to: actor, visible: true, published: Time.utc)
    let_create!(:pin_relationship, actor: actor, object: pinned_object)
    let_create(:object, named: tail1, attributed_to: actor, visible: true)
    let_create(:object, named: tail2, attributed_to: actor, visible: true)
    let_create(:object, named: tail3, attributed_to: actor, visible: true)

    let(tail) do
      Ktistec::Util::PaginatedArray(ActivityPub::Object).new.tap do |t|
        t << tail1
        t << tail2
        t << tail3
        t.cursor_end = tail3.id
        t.has_next = false
      end
    end

    context "when the tail has no previous page" do
      before_each { tail.has_prev = false }

      it "returns pinned posts and the tail" do
        pinned, result = self.class.cursor_paginate_with_pins(actor, 10) { tail }
        expect(pinned.map(&.id)).to eq([pinned_object.id])
        expect(result.map(&.id)).to eq([tail1.id, tail2.id, tail3.id])
      end
    end

    context "when the tail has a previous page" do
      before_each { tail.has_prev = true }

      it "returns no pinned posts and the tail" do
        pinned, result = self.class.cursor_paginate_with_pins(actor, 10) { tail }
        expect(pinned).to be_empty
        expect(result.map(&.id)).to eq([tail1.id, tail2.id, tail3.id])
      end
    end

    it "trims the tail" do
      _, result = self.class.cursor_paginate_with_pins(actor, 2) { tail }
      expect(result.map(&.id)).to eq([tail1.id])
      expect(result.cursor_end).to eq(tail1.id)
      expect(result.has_next?).to be_true
    end

    it "does not mutate the tail" do
      self.class.cursor_paginate_with_pins(actor, 2) { tail }
      expect(tail.map(&.id)).to eq([tail1.id, tail2.id, tail3.id])
      expect(tail.cursor_end).to eq(tail3.id)
      expect(tail.has_next?).to be_false
    end
  end

  describe "link_header" do
    let(collection) { Ktistec::Util::PaginatedArray(String).new }

    macro header
      self.class.link_header("/api/v1/timelines/home", collection, 20)
    end

    it "returns nil" do
      expect(header).to be_nil
    end

    context "with cursor_start" do
      before_each do
        collection.cursor_start = 100_i64
      end

      it "returns nil" do
        expect(header).to be_nil
      end

      context "and has_prev" do
        before_each { collection.has_prev = true }

        it "includes prev link" do
          expect(header).to eq(%Q(<https://test.test/api/v1/timelines/home?min_id=100&limit=20>; rel="prev"))
        end
      end
    end

    context "with cursor_end" do
      before_each do
        collection.cursor_end = 50_i64
      end

      it "returns nil" do
        expect(header).to be_nil
      end

      context "and has_next" do
        before_each { collection.has_next = true }

        it "includes next link" do
          expect(header).to contain(%Q(<https://test.test/api/v1/timelines/home?max_id=50&limit=20>; rel="next"))
        end
      end
    end
  end
end
