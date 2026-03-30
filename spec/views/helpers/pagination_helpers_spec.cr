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
        XML.parse_html(self.class.paginate(env, collection), PARSER_OPTIONS).document
      rescue XML::Error
        XML.parse_html("<div/>", PARSER_OPTIONS).document
      end
    end

    it "does not render pagination controls" do
      expect(subject.xpath_nodes("/nav[contains(@class,'pagination')]")).to be_empty
    end

    context "with offset pagination" do
      context "with more pages" do
        before_each { collection.more = true }

        it "renders the next link" do
          expect(subject.xpath_nodes("//a/@href")).to contain_exactly("?page=2")
        end
      end

      context "on the second page" do
        let(query) { "?page=2" }

        it "renders the prev link" do
          expect(subject.xpath_nodes("//a/@href")).to contain_exactly("?page=1")
        end
      end
    end

    context "with cursor pagination" do
      before_each do
        collection.cursor_start = 100_i64
        collection.cursor_end = 50_i64
      end

      it "renders the prev link" do
        expect(subject.xpath_nodes("//a/@href")).to contain_exactly("?min_id=100")
      end

      it "does not render the next link" do
        expect(subject.xpath_nodes("//a/@href")).not_to contain("?max_id=50")
      end

      context "with more results" do
        before_each { collection.more = true }

        it "renders the prev link" do
          expect(subject.xpath_nodes("//a/@href")).to contain("?min_id=100")
        end

        it "renders the next link" do
          expect(subject.xpath_nodes("//a/@href")).to contain("?max_id=50")
        end
      end
    end
  end

  describe "pagination_params" do
    it "ensures page is at least 1" do
      env = make_env("GET", "/?page=0")
      result = self.class.pagination_params(env)
      expect(result[:page]).to eq(1)
    end

    it "ignores negative page numbers" do
      env = make_env("GET", "/?page=-5")
      result = self.class.pagination_params(env)
      expect(result[:page]).to eq(1)
    end

    context "when user is not authenticated" do
      it "allows size up to 20" do
        env = make_env("GET", "/?page=2&size=20")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(2)
        expect(result[:size]).to eq(20)
      end

      it "limits size to 20" do
        env = make_env("GET", "/?page=2&size=21")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(2)
        expect(result[:size]).to eq(20)
      end

      it "uses default size of 10 when no size specified" do
        env = make_env("GET", "/?page=1")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(1)
        expect(result[:size]).to eq(10)
      end

      it "uses requested size when under the limit" do
        env = make_env("GET", "/?size=15")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(1)
        expect(result[:size]).to eq(15)
      end
    end

    context "when user is authenticated" do
      sign_in

      it "allows size up to 1000" do
        env = make_env("GET", "/?page=3&size=1000")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(3)
        expect(result[:size]).to eq(1000)
      end

      it "limits size to 1000" do
        env = make_env("GET", "/?size=1001")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(1)
        expect(result[:size]).to eq(1000)
      end

      it "uses default size of 10 when no size specified" do
        env = make_env("GET", "/?page=1")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(1)
        expect(result[:size]).to eq(10)
      end

      it "uses requested size when under the limit" do
        env = make_env("GET", "/?size=500")
        result = self.class.pagination_params(env)
        expect(result[:page]).to eq(1)
        expect(result[:size]).to eq(500)
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

  describe "link_header" do
    let(collection) { Ktistec::Util::PaginatedArray(String).new }

    it "returns nil" do
      expect(self.class.link_header("/api/v1/timelines/home", collection, 20)).to be_nil
    end

    context "with cursor_start" do
      before_each do
        collection.cursor_start = 100_i64
      end

      it "includes prev link" do
        result = self.class.link_header("/api/v1/timelines/home", collection, 20)
        expect(result).to eq(%Q(<https://test.test/api/v1/timelines/home?min_id=100&limit=20>; rel="prev"))
      end
    end

    context "with cursor_end and more" do
      before_each do
        collection.cursor_end = 50_i64
        collection.more = true
      end

      it "includes next link" do
        result = self.class.link_header("/api/v1/timelines/home", collection, 20)
        expect(result).to contain(%Q(<https://test.test/api/v1/timelines/home?max_id=50&limit=20>; rel="next"))
      end
    end
  end
end
