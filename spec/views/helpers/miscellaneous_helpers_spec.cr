require "./support_spec"

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  PARSER_OPTIONS =
    XML::HTMLParserOptions::NOIMPLIED |
      XML::HTMLParserOptions::NODEFDTD

  describe ".addressing" do
    let_build(:actor, local: true)

    context "when visibility is public" do
      let(params) { {"visibility" => "public"} }

      it "puts public collection in to field" do
        _, to, _ = self.class.addressing(params, actor)
        expect(to).to contain("https://www.w3.org/ns/activitystreams#Public")
      end

      it "puts followers collection in cc field" do
        _, _, cc = self.class.addressing(params, actor)
        expect(cc).to contain(actor.followers)
      end

      it "returns visible as true" do
        visible, _, _ = self.class.addressing(params, actor)
        expect(visible).to be_true
      end
    end

    context "when visibility is private" do
      let(params) { {"visibility" => "private"} }

      it "puts followers collection in to field" do
        _, to, _ = self.class.addressing(params, actor)
        expect(to).to contain(actor.followers)
      end

      it "does not put followers collection in cc field" do
        _, _, cc = self.class.addressing(params, actor)
        expect(cc).not_to contain(actor.followers)
      end

      it "returns visible as false" do
        visible, _, _ = self.class.addressing(params, actor)
        expect(visible).to be_false
      end
    end

    context "when visibility is direct" do
      let(params) { {"visibility" => "direct"} }

      it "does not put anything in to field" do
        _, to, _ = self.class.addressing(params, actor)
        expect(to).to be_empty
      end

      it "does not put anything in cc field" do
        _, _, cc = self.class.addressing(params, actor)
        expect(cc).to be_empty
      end

      it "returns visible as false" do
        visible, _, _ = self.class.addressing(params, actor)
        expect(visible).to be_false
      end
    end
  end

  describe ".visibility" do
    let_build(:object, local: true)
    let(actor) { object.attributed_to }

    context "when object addresses the public collection" do
      it "returns public" do
        object.assign(to: ["https://www.w3.org/ns/activitystreams#Public", "https://remote/actors/foo"], cc: nil)
        expect(self.class.visibility(actor, object)).to eq("public")
      end
    end

    context "when object addresses the public collection" do
      it "returns public" do
        object.assign(to: ["https://remote/actors/foo"], cc: ["https://www.w3.org/ns/activitystreams#Public"])
        expect(self.class.visibility(actor, object)).to eq("public")
      end
    end

    context "when object addresses the followers collection" do
      it "returns private" do
        object.assign(to: [actor.followers.not_nil!, "https://remote/actors/foo"], cc: nil)
        expect(self.class.visibility(actor, object)).to eq("private")
      end
    end

    context "when object addresses the followers collection" do
      it "returns private" do
        object.assign(to: ["https://remote/actors/foo"], cc: [actor.followers.not_nil!])
        expect(self.class.visibility(actor, object)).to eq("private")
      end
    end

    context "when object addresses neither the public collection nor the followers collection" do
      it "returns direct" do
        object.assign(to: ["https://remote/actors/foo"], cc: ["https://remote/actors/bar"])
        expect(self.class.visibility(actor, object)).to eq("direct")
      end
    end

    context "when both to and cc are empty arrays" do
      it "returns direct" do
        object.assign(to: [] of String, cc: [] of String)
        expect(self.class.visibility(actor, object)).to eq("direct")
      end
    end

    context "when both to and cc are nil" do
      context "and object is not a reply" do
        it "returns public" do
          object.assign(to: nil, cc: nil)
          expect(self.class.visibility(actor, object)).to eq("public")
        end
      end

      context "and object is a reply" do
        let_build(:object, named: :parent)

        before_each { object.assign(to: nil, cc: nil, in_reply_to: parent) }

        context "and parent addresses the public collection" do
          it "returns public" do
            object.assign(to: nil, cc: ["https://www.w3.org/ns/activitystreams#Public", "https://remote/actors/foo"])
            expect(self.class.visibility(actor, object)).to eq("public")
          end
        end

        context "and parent addresses the public collection" do
          it "returns public" do
            object.assign(to: ["https://www.w3.org/ns/activitystreams#Public"], cc: ["https://remote/actors/foo"])
            expect(self.class.visibility(actor, object)).to eq("public")
          end
        end

        context "and parent addresses the followers collection" do
          it "returns direct" do
            parent.assign(to: [actor.followers.not_nil!], cc: nil)
            expect(self.class.visibility(actor, object)).to eq("direct")
          end
        end

        context "and parent addresses the followers collection" do
          it "returns direct" do
            parent.assign(to: nil, cc: [actor.followers.not_nil!])
            expect(self.class.visibility(actor, object)).to eq("direct")
          end
        end
      end
    end
  end

  describe ".wrap_filter_term" do
    let(term) { "%f\\%o\\_o_" }

    subject { XML.parse_html(self.class.wrap_filter_term(term), PARSER_OPTIONS) }

    it "wraps a filter term in a span" do
      expect(subject.xpath_nodes("/span/@class")).to contain_exactly("ui filter term")
    end

    it "wraps a wildcard % in a span" do
      expect(subject.xpath_nodes("/span/span[contains(@class,'wildcard')]/text()")).to contain("%")
    end

    it "wraps a wildcard _ in a span" do
      expect(subject.xpath_nodes("/span/span[contains(@class,'wildcard')]/text()")).to contain("_")
    end

    it "wraps an escaped wildcard % in a span" do
      expect(subject.xpath_nodes("/span/span[contains(@class,'wildcard')]/text()")).to contain("\\%")
    end

    it "wraps an escaped wildcard _ in a span" do
      expect(subject.xpath_nodes("/span/span[contains(@class,'wildcard')]/text()")).to contain("\\_")
    end

    it "does not wrap text" do
      expect(subject.xpath_nodes("/span/text()")).to contain("f", "o")
    end
  end

  describe ".normalize_params" do
    context "given URI::Params" do
      it "converts single values to strings" do
        params = URI::Params.parse("name=Alice&age=30")
        result = self.class.normalize_params(params)
        expect(result["name"]).to eq("Alice")
        expect(result["age"]).to eq("30")
      end

      it "omits empty values" do
        params = URI::Params.parse("empty=")
        result = self.class.normalize_params(params)
        expect(result.has_key?("empty")).to be_false
      end

      it "converts multiple values to arrays" do
        params = URI::Params.parse("tags=ruby&tags=crystal&tags=go")
        result = self.class.normalize_params(params)
        expect(result["tags"]).to eq(["ruby", "crystal", "go"])
      end

      it "omits empty values from arrays" do
        params = URI::Params.parse("tags=ruby&tags=&tags=crystal&tags=&tags=go")
        result = self.class.normalize_params(params)
        expect(result["tags"]).to eq(["ruby", "crystal", "go"])
      end
    end

    context "given Hash(String, JSON::Any::Type)" do
      it "converts primitive values to strings" do
        params = Hash(String, JSON::Any::Type){"name" => "Alice", "age" => 30_i64, "active" => true, "score" => 95_f64}
        result = self.class.normalize_params(params)
        expect(result["name"]).to eq("Alice")
        expect(result["age"]).to eq("30")
        expect(result["active"]).to eq("true")
        expect(result["score"]).to eq("95.0")
      end

      it "omits null values" do
        params = Hash(String, JSON::Any::Type){"empty" => nil}
        result = self.class.normalize_params(params)
        expect(result.has_key?("empty")).to be_false
      end

      it "converts arrays to arrays of strings" do
        params = Hash(String, JSON::Any::Type){"tags" => [JSON::Any.new("ruby"), JSON::Any.new("crystal"), JSON::Any.new("go")]}
        result = self.class.normalize_params(params)
        expect(result["tags"]).to eq(["ruby", "crystal", "go"])
      end

      it "omits null values from arrays" do
        params = Hash(String, JSON::Any::Type){"tags" => [JSON::Any.new("ruby"), JSON::Any.new(nil), JSON::Any.new("crystal"), JSON::Any.new(nil), JSON::Any.new("go")]}
        result = self.class.normalize_params(params)
        expect(result["tags"]).to eq(["ruby", "crystal", "go"])
      end

      it "raises error for nested objects" do
        params = Hash(String, JSON::Any::Type){"user" => {"name" => JSON::Any.new("Alice")}}
        expect { self.class.normalize_params(params) }.to raise_error(Exception)
      end
    end
  end

  describe "host" do
    it "returns the host" do
      expect(host).to eq("https://test.test")
    end
  end

  describe "sanitize" do
    it "sanitizes HTML" do
      expect(s("<body>Foo Bar</body>")).to eq("Foo Bar")
    end
  end

  describe "render_as_text" do
    it "strips all HTML" do
      expect(t("<p>Foo Bar</p>")).to eq("Foo Bar\n")
    end
  end

  describe "pluralize" do
    it "pluralizes the noun" do
      expect(pluralize(0, "fox")).to eq("fox")
    end

    it "does not pluralize the noun" do
      expect(pluralize(1, "fox")).to eq("1 fox")
    end

    it "pluralizes the noun" do
      expect(pluralize(2, "fox")).to eq("2 foxes")
    end
  end

  describe "comma" do
    it "emits a comma" do
      expect(comma([1, 2, 3], 1)).to eq(",")
    end

    it "does not emit a comma" do
      expect(comma([1, 2, 3], 2)).to eq("")
    end
  end

  describe "markdown_to_html" do
    subject do
      markdown = <<-MD
      Markdown
      ========
      MD
      XML.parse_html(markdown_to_html(markdown), PARSER_OPTIONS).document
    end

    it "transforms Markdown to HTML" do
      expect(subject.xpath_nodes("/h1/text()")).to contain_exactly("Markdown")
    end
  end

  describe "id" do
    it "generates an id" do
      expect(id).to match(/^[a-zA-Z0-9_-]+$/)
    end
  end

  describe "task_status_line" do
    def_double :task,
      complete: false,
      running: false,
      backtrace: nil.as(Array(String)?),
      next_attempt_at: nil.as(Time?),
      last_attempt_at: nil.as(Time?)

    subject do
      task_status_line(task)
    end

    context "given a task that is complete" do
      let(task) { new_double(:task, complete: true) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a task that is running" do
      let(task) { new_double(:task, running: true) }

      it "returns the status" do
        expect(subject).to match(/Running/)
      end
    end

    context "given a task that isn't scheduled" do
      let(task) { new_double(:task) }

      it "returns the status" do
        expect(subject).to match(/The task isn't scheduled./)
      end
    end

    context "given a task that is ready to run" do
      let(task) { new_double(:task, next_attempt_at: 1.second.ago) }

      it "returns the status" do
        expect(subject).to match(/The next run is imminent./)
      end
    end

    context "given a task that will run" do
      let(task) { new_double(:task, next_attempt_at: 50.minutes.from_now) }

      it "returns the status" do
        expect(subject).to match(/The next run is in about 1 hour./)
      end
    end

    context "when detail is true" do
      subject do
        task_status_line(task, detail: true)
      end

      context "given a task that previously ran" do
        let(task) { new_double(:task, last_attempt_at: 50.minutes.ago) }

        it "returns the status" do
          expect(subject).to match(/The last run was about 1 hour ago./)
        end
      end
    end

    context "given a task that has failed" do
      let(task) { new_double(:task, backtrace: ["Runtime error"]) }

      it "returns the status" do
        expect(subject).to match(/The task failed./)
      end
    end
  end

  describe "fetch_task_status_line" do
    def_double :fetch_task,
      complete: false,
      running: false,
      backtrace: nil.as(Array(String)?),
      next_attempt_at: nil.as(Time?),
      last_attempt_at: nil.as(Time?),
      last_success_at: nil.as(Time?)

    def_double :published_object,
      published: nil.as(Time?)

    subject do
      fetch_task_status_line(task)
    end

    context "given a task that is complete" do
      let(task) { new_double(:fetch_task, complete: true) }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "given a task that is running" do
      let(task) { new_double(:fetch_task, running: true) }

      it "returns the status" do
        expect(subject).to match(/Checking for new posts./)
      end

      context "and a collection of published objects" do
        let(collection) do
          [
            new_double(:published_object, published: 50.hours.ago),
            new_double(:published_object, published: 70.hours.ago),
          ]
        end

        subject do
          fetch_task_status_line(task, collection)
        end

        it "includes status of most recent post" do
          expect(subject).to match(/The most recent post was about 2 days ago./)
        end
      end
    end

    context "given a task that isn't scheduled" do
      let(task) { new_double(:fetch_task) }

      it "returns the status" do
        expect(subject).to match(/The next check for new posts isn't scheduled./)
      end
    end

    context "given a task that is ready to run" do
      let(task) { new_double(:fetch_task, next_attempt_at: 1.second.ago) }

      it "returns the status" do
        expect(subject).to match(/The next check for new posts is imminent./)
      end
    end

    context "given a task that will run" do
      let(task) { new_double(:fetch_task, next_attempt_at: 50.minutes.from_now) }

      it "returns the status" do
        expect(subject).to match(/The next check for new posts is in about 1 hour./)
      end
    end

    context "when detail is true" do
      subject do
        fetch_task_status_line(task, detail: true)
      end

      context "given a task that previously ran" do
        let(task) { new_double(:fetch_task, last_attempt_at: 50.minutes.ago) }

        it "returns the status" do
          expect(subject).to match(/The last check was about 1 hour ago./)
        end
      end

      context "given a task with a successful fetch" do
        let(task) { new_double(:fetch_task, last_success_at: 50.minutes.ago) }

        it "returns the status" do
          expect(subject).to match(/The last new post was fetched about 1 hour ago./)
        end
      end
    end

    context "given a task that has failed" do
      let(task) { new_double(:fetch_task, backtrace: ["Runtime error"]) }

      it "returns the status" do
        expect(subject).to match(/The task failed./)
      end
    end
  end
end
