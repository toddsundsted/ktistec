require "../../src/views/view_helper"

require "../spec_helper/controller"

class FooBarController
  include Ktistec::Controller

  skip_auth [
    "/foo/bar/id_param/:id",
    "/foo/bar/iri_param/:id"
  ]

  get "/foo/bar/id_param/:id" do |env|
    id_param(env).to_s
  end

  get "/foo/bar/iri_param/:id" do |env|
    iri_param(env, "/foo/bar").to_s
  end
end

Spectator.describe FooBarController do
  describe "GET /foo/bar/id_param/:id" do
    it "is not successful for non-numeric parameters" do
      get "/foo/bar/id_param/five"
      expect(response.status_code).to eq(400)
    end

    it "is successful for numeric parameters" do
      get "/foo/bar/id_param/5"
      expect(response.status_code).to eq(200)
    end

    it "it returns the id of the resource" do
      get "/foo/bar/id_param/5"
      expect(response.body).to eq("5")
    end
  end

  describe "GET /foo/bar/iri_param/:id" do
    it "is not successful for invalid parameters" do
      get "/foo/bar/iri_param/+"
      expect(response.status_code).to eq(400)
    end

    it "is successful for valid parameters" do
      get "/foo/bar/iri_param/000"
      expect(response.status_code).to eq(200)
    end

    it "it returns the IRI of the resource" do
      get "/foo/bar/iri_param/000"
      expect(response.body).to eq("https://test.test/foo/bar/000")
    end
  end
end

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  class Model
    property field = "Value"
    getter errors = {"field" => ["is wrong"]}
  end

  let(model) { Model.new }

  let(collection) { Ktistec::Util::PaginatedArray(Model).new }

  ## HTML helpers

  PARSER_OPTIONS =
    XML::HTMLParserOptions::NOIMPLIED |
    XML::HTMLParserOptions::NODEFDTD

  describe "paginate" do
    let(query) { "" }

    let(env) { env_factory("GET", "/#{query}") }

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

  describe "activity_button" do
    subject do
      XML.parse_html(activity_button("/foobar", "https://object", "Zap", method: "PUT", form_class: "blarg", button_class: "honk", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("/form/button/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("/form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "emits a form with a hidden input specifying the object" do
      expect(subject.xpath_nodes("/form/input[@name='object']/@value")).to contain_exactly("https://object")
    end

    it "emits a form with a hidden input specifying the type" do
      expect(subject.xpath_nodes("/form/input[@name='type']/@value")).to contain_exactly("Zap")
    end

    it "emits a form with a hidden input specifying the visibility" do
      expect(subject.xpath_nodes("/form/input[@name='public']/@value")).to contain_exactly("1")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("/form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("/form/@method")).to contain_exactly("PUT")
    end

    it "specifies the form class" do
      expect(subject.xpath_nodes("/form/@class")).to contain_exactly("blarg")
    end

    it "specifies the button class" do
      expect(subject.xpath_nodes("/form/button/@class")).to contain_exactly("honk")
    end

    context "without a body" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", csrf: nil), PARSER_OPTIONS).document
      end

      it "emits a form with nested content" do
        expect(subject.xpath_nodes("/form/button/text()")).to contain_exactly("Label")
      end
    end

    context "given data attributes" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", form_data: {"foo" => "bar", "abc" => "xyz"}, button_data: {"one" => "1", "two" => "2"}, csrf: nil), PARSER_OPTIONS).document
      end

      it "emits form data attributes" do
        expect(subject.xpath_nodes("/form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end

      it "emits button data attributes" do
        expect(subject.xpath_nodes("/form/button/@*[starts-with(name(),'data-')]")).to contain_exactly("1", "2")
      end
    end

    context "given a DELETE method" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", method: "DELETE", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "emits a hidden input" do
        expect(subject.xpath_nodes("/form/input[@type='hidden'][@name='_method']/@value")).to contain_exactly("delete")
      end

      it "sets the method to POST" do
        expect(subject.xpath_nodes("/form/@method")).to contain_exactly("POST")
      end
    end

    context "given a GET method" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", method: "GET", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
      end

      it "does not emit a csrf token" do
        expect(subject.xpath_nodes("/form/input[@name='authenticity_token']")).to be_empty
      end
    end
  end

  describe "form_button" do
    subject do
      XML.parse_html(form_button("/foobar", method: "PUT", form_class: "blarg", button_class: "honk", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("/form/button/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("/form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("/form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("/form/@method")).to contain_exactly("PUT")
    end

    it "specifies the form class" do
      expect(subject.xpath_nodes("/form/@class")).to contain_exactly("blarg")
    end

    it "specifies the button class" do
      expect(subject.xpath_nodes("/form/button/@class")).to contain_exactly("honk")
    end

    context "without a body" do
      subject do
        XML.parse_html(form_button("Label", "/foobar", csrf: nil), PARSER_OPTIONS).document
      end

      it "emits a form with nested content" do
        expect(subject.xpath_nodes("/form/button/text()")).to contain_exactly("Label")
      end
    end

    context "given data attributes" do
      subject do
        XML.parse_html(form_button("Label", "/foobar", form_data: {"foo" => "bar", "abc" => "xyz"}, button_data: {"one" => "1", "two" => "2"}, csrf: nil), PARSER_OPTIONS).document
      end

      it "emits form data attributes" do
        expect(subject.xpath_nodes("/form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end

      it "emits button data attributes" do
        expect(subject.xpath_nodes("/form/button/@*[starts-with(name(),'data-')]")).to contain_exactly("1", "2")
      end
    end

    context "given a DELETE method" do
      subject do
        XML.parse_html(form_button("/foobar", method: "DELETE", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "emits a hidden input" do
        expect(subject.xpath_nodes("/form/input[@type='hidden'][@name='_method']/@value")).to contain_exactly("delete")
      end

      it "sets the method to POST" do
        expect(subject.xpath_nodes("/form/@method")).to contain_exactly("POST")
      end
    end

    context "given a GET method" do
      subject do
        XML.parse_html(form_button("/foobar", method: "GET", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
      end

      it "does not emit a csrf token" do
        expect(subject.xpath_nodes("/form/input[@name='authenticity_token']")).to be_empty
      end
    end
  end

  describe "authenticity_token" do
    let(env) { env_factory("GET", "/") }

    subject do
      XML.parse_html(authenticity_token(env), PARSER_OPTIONS).document
    end

    before_each { env.session.string("csrf", "TOKEN") }

    it "emits input tag with the authenticity token" do
      expect(subject.xpath_nodes("/input[@type='hidden'][@name='authenticity_token']/@value")).to have("TOKEN")
    end
  end

  describe "error_messages" do
    subject do
      XML.parse_html(error_messages(model), PARSER_OPTIONS).document
    end

    it "emits nested div containing error message" do
      expect(subject.xpath_nodes("/div/div/text()")).to contain_exactly("field is wrong")
    end
  end

  describe "form_tag" do
    subject do
      XML.parse_html(form_tag(model, "/foobar", method: "PUT", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("/form/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("/form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("/form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("/form/@method")).to contain_exactly("PUT")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("/form/@class")).to contain_exactly("ui form error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", data: {"foo" => "bar", "abc" => "xyz"}, csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("/form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(form_tag(nil, "/foobar", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("/form/@class")).to contain_exactly("ui form")
      end
    end

    context "given a DELETE method" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", method: "DELETE", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "emits a hidden input" do
        expect(subject.xpath_nodes("/form/input[@type='hidden'][@name='_method']/@value")).to contain_exactly("delete")
      end

      it "sets the method to POST" do
        expect(subject.xpath_nodes("/form/@method")).to contain_exactly("POST")
      end
    end

    context "given a GET method" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", method: "GET", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
      end

      it "does not emit a csrf token" do
        expect(subject.xpath_nodes("/form/input[@name='authenticity_token']")).to be_empty
      end

      it "sets the method to GET" do
        expect(subject.xpath_nodes("/form/@method")).to contain_exactly("GET")
      end
    end
  end

  describe "input_tag" do
    subject do
      XML.parse_html(input_tag("Label", model, field, class: "blarg", type: "foobar", placeholder: "quoz"), PARSER_OPTIONS).document
    end

    it "emits div containing label and input tags" do
      expect(subject.xpath_nodes("/div[label][input]")).not_to be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("/div/label/text()")).to contain_exactly("Label")
    end

    it "emits an input tag with the specified name" do
      expect(subject.xpath_nodes("/div/input/@name")).to contain_exactly("field")
    end

    it "emits an input tag with the associated value" do
      expect(subject.xpath_nodes("/div/input/@value")).to contain_exactly("Value")
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("/div/input/@class")).to contain_exactly("blarg")
    end

    it "overrides the default type" do
      expect(subject.xpath_nodes("/div/input/@type")).to contain_exactly("foobar")
    end

    it "specifies the placeholder" do
      expect(subject.xpath_nodes("/div/input/@placeholder")).to contain_exactly("quoz")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(input_tag("Label", model, field, data: {"foo" => "bar", "abc" => "xyz"}), PARSER_OPTIONS).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("/div/input/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(input_tag("Label", nil, field), PARSER_OPTIONS).document
      end

      it "emits an input tag with the specified name" do
        expect(subject.xpath_nodes("/div/input/@name")).to contain_exactly("field")
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field")
      end
    end

    context "given a value with an ampersand and quotes" do
      before_each do
        model.field = %q|Value with ampersand & "quotes".|
      end

      it "emits an input tag with the associated value" do
        expect(subject.xpath_nodes("/div/input/@value")).to contain_exactly(%q|Value with ampersand & "quotes".|)
      end
    end
  end

  describe "select_tag" do
    subject do
      XML.parse_html(select_tag("Label", model, field, {one: "One", two: "Two"}, class: "blarg"), PARSER_OPTIONS).document
    end

    it "emits div containing label and select tags" do
      expect(subject.xpath_nodes("/div[label][select]")).not_to be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("/div/label/text()")).to contain_exactly("Label")
    end

    it "emits a select tag with the specified name" do
      expect(subject.xpath_nodes("/div/select/@name")).to contain_exactly("field")
    end

    it "emits option tags with the specified values" do
      expect(subject.xpath_nodes("/div/select/option/@value")).to contain_exactly("one", "two")
    end

    it "emits option tags with the specified text" do
      expect(subject.xpath_nodes("/div/select/option/text()")).to contain_exactly("One", "Two")
    end

    context "given a field value that matches an option" do
      before_each { model.field = "one" }

      it "emits an option tag with the option selected" do
        expect(subject.xpath_nodes("/div/select/option[@selected]/text()")).to contain_exactly("One")
      end
    end

    context "given a selected value that matches an option" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"}, selected: :two), PARSER_OPTIONS).document
      end

      it "emits an option tag with the option selected" do
        expect(subject.xpath_nodes("/div/select/option[@selected]/text()")).to contain_exactly("Two")
      end
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("/div/select/@class")).to contain_exactly("blarg")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"}, data: {"foo" => "bar", "abc" => "xyz"}), PARSER_OPTIONS).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("/div/select/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"}), PARSER_OPTIONS).document
      end

      it "emits a select tag with the specified name" do
        expect(subject.xpath_nodes("/div/select/@name")).to contain_exactly("field")
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field")
      end
    end
  end

  describe "submit_button" do
    subject do
      XML.parse_html(submit_button("Text", class: "blarg"), PARSER_OPTIONS).document
    end

    it "emits an input of type submit" do
      expect(subject.xpath_nodes("/input[@type='submit']")).not_to be_empty
    end

    it "specifies the value" do
      expect(subject.xpath_nodes("/input[@type='submit']/@value")).to contain_exactly("Text")
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("/input[@type='submit']/@class")).to contain_exactly("blarg")
    end
  end

  describe "params_to_inputs", tag: :tag do
    let(params) { URI::Params.parse("one=1&two=2") }
    let(exclude_list) { nil }
    let(include_list) { nil }

    subject do
      XML.parse_html(params_to_inputs(params, exclude: exclude_list, include: include_list)).document
    end

    it "emits hidden fields" do
      expect(subject.xpath_nodes("//input[@type='hidden']/@name")).to contain_exactly("one", "two")
      expect(subject.xpath_nodes("//input[@type='hidden']/@value")).to contain_exactly("1", "2")
    end

    context "emits hidden field" do
      let(exclude_list) { ["one"] }

      it "emits hidden field" do
        expect(subject.xpath_nodes("//input[@type='hidden']/@name")).to contain_exactly("two")
        expect(subject.xpath_nodes("//input[@type='hidden']/@value")).to contain_exactly("2")
      end
    end

    context "emits hidden field" do
      let(include_list) { ["one"] }

      it "emits hidden field" do
        expect(subject.xpath_nodes("//input[@type='hidden']/@name")).to contain_exactly("one")
        expect(subject.xpath_nodes("//input[@type='hidden']/@value")).to contain_exactly("1")
      end
    end
  end

  ## JSON helpers

  describe "activity_pub_collection" do
    let(query) { "" }

    let(env) { env_factory("GET", "/#{query}") }

    let(host) { Ktistec.settings.host }

    subject do
      JSON.parse(String.build { |content_io|
        activity_pub_collection(collection)
      })
    end

    it "generates a JSON-LD document" do
      expect(subject["@context"]).to eq("https://www.w3.org/ns/activitystreams")
    end

    it "is an ordered collection" do
      expect(subject["type"]).to eq("OrderedCollection")
    end

    it "nests the first page of items" do
      expect(subject["first"]["id"]).to eq("https://test.test/?page=1")
    end

    context "the first page of items" do
      subject { super["first"] }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]).to be_truthy
      end

      it "does not include a link to the next page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?page=2")
        end
      end
    end

    context "the second page of items" do
      let(query) { "?page=2" }

      it "is an ordered collection page" do
        expect(subject["type"]).to eq("OrderedCollectionPage")
      end

      it "includes an ordered collection of items" do
        expect(subject["orderedItems"]?).to be_truthy
      end

      it "includes a link to the previous page" do
        expect(subject["prev"]?).to eq("https://test.test/?page=1")
      end

      it "does not include a link to the previous page" do
        expect(subject["next"]?).to be_nil
      end

      context "with more pages" do
        before_each { collection.more = true }

        it "includes a link to the next page" do
          expect(subject["next"]?).to eq("https://test.test/?page=3")
        end
      end
    end
  end

  describe "error_block" do
    subject do
      error_block(model, false)
    end

    it "emits a block of errors" do
      expect(subject).to eq(%q|"errors":{"field":["is wrong"]}|)
    end
  end

  describe "field_pair" do
    subject do
      field_pair(model, field, false)
    end

    it "emits a key/value pair" do
      expect(subject).to eq(%q|"field":"Value"|)
    end
  end

  ## Task helpers

  describe "fetch_task_status_line" do
    def_double :fetch_task,
      complete: false,
      running: false,
      backtrace: nil.as(Array(String)?),
      next_attempt_at: nil.as(Time?)

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
        expect(subject).to eq("Checking for new posts.")
      end

      context "and a collection of published objects" do
        let(collection) do
          [
            new_double(:published_object, published: 50.hours.ago),
            new_double(:published_object, published: 70.hours.ago)
          ]
        end

        subject do
          fetch_task_status_line(task, collection)
        end

        it "includes status of most recent post" do
          expect(subject).to eq("Checking for new posts. The most recent post was about 2 days ago.")
        end
      end
    end

    context "given a task that hasn't run" do
      let(task) { new_double(:fetch_task) }

      it "returns the status" do
        expect(subject).to eq("The next check for new posts is imminent.")
      end
    end

    context "given a task that is ready to run" do
      let(task) { new_double(:fetch_task, next_attempt_at: 1.second.ago) }

      it "returns the status" do
        expect(subject).to eq("The next check for new posts is imminent.")
      end
    end

    context "given a task that will run" do
      let(task) { new_double(:fetch_task, next_attempt_at: 50.minutes.from_now) }

      it "returns the status" do
        expect(subject).to eq("The next check for new posts is in about 1 hour.")
      end
    end

    context "given a task that has failed" do
      let(task) { new_double(:fetch_task, backtrace: ["Runtime error"]) }

      it "returns the status" do
        expect(subject).to eq("The task failed.")
      end
    end
  end

  ## General purpose helpers

  describe "sanitize" do
    it "sanitizes HTML" do
      expect(s("<body>Foo Bar</body>")).to eq("Foo Bar")
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

  describe "id" do
    it "generates an id" do
      expect(id).to match(/^[a-zA-Z0-9_-]+$/)
    end
  end

  ## Path helpers

  double :path_double do
    stub def id
      42
    end

    stub def uid
      "xyz"
    end
  end

  describe "back_path" do
    let(env) do
      env_factory("GET", "/filters/17").tap do |env|
        env.request.headers["Referer"] = "/back"
      end
    end

    it "gets the back path" do
      expect(back_path).to eq("/back")
    end
  end

  describe "home_path" do
    it "gets the home path" do
      expect(home_path).to eq("/")
    end
  end

  describe "sessions_path" do
    it "gets the sessions path" do
      expect(sessions_path).to eq("/sessions")
    end
  end

  describe "search_path" do
    it "gets the search path" do
      expect(search_path).to eq("/search")
    end
  end

  describe "settings_path" do
    it "gets the settings path" do
      expect(settings_path).to eq("/settings")
    end
  end

  describe "filters_path" do
    it "gets the filters path" do
      expect(filters_path).to eq("/filters")
    end
  end

  describe "filter_path" do
    let(env) do
      env_factory("GET", "/filters/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given a term" do
      let(term) { double(:path_double) }

      it "gets the filter path" do
        expect(filter_path(term)).to eq("/filters/42")
      end
    end

    it "gets the filter path" do
      expect(filter_path).to eq("/filters/17")
    end
  end

  describe "metrics_path" do
    it "gets the metrics path" do
      expect(metrics_path).to eq("/metrics")
    end
  end

  describe "remote_activity_path" do
    let(env) do
      env_factory("GET", "/remote/activities/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an activity" do
      let(activity) { double(:path_double) }

      it "gets the remote activity path" do
        expect(remote_activity_path(activity)).to eq("/remote/activities/42")
      end
    end

    it "gets the remote activity path" do
      expect(remote_activity_path).to eq("/remote/activities/17")
    end
  end

  describe "activity_path" do
    let(env) do
      env_factory("GET", "/activities/abc").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an activity" do
      let(activity) { double(:path_double) }

      it "gets the activity path" do
        expect(activity_path(activity)).to eq("/activities/xyz")
      end
    end

    it "gets the activity path" do
      expect(activity_path).to eq("/activities/abc")
    end
  end

  describe "anchor" do
    let(env) do
      env_factory("GET", "/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the anchor" do
        expect(anchor(object)).to eq("object-42")
      end
    end

    it "gets the anchor" do
      expect(anchor).to eq("object-17")
    end
  end

  describe "objects_path" do
    it "gets the objects path" do
      expect(objects_path).to eq("/objects")
    end
  end

  describe "remote_object_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the remote object path" do
        expect(remote_object_path(object)).to eq("/remote/objects/42")
      end
    end

    it "gets the remote object path" do
      expect(remote_object_path).to eq("/remote/objects/17")
    end
  end

  describe "object_path" do
    let(env) do
      env_factory("GET", "/objects/abc").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the object path" do
        expect(object_path(object)).to eq("/objects/xyz")
      end
    end

    it "gets the object path" do
      expect(object_path).to eq("/objects/abc")
    end
  end

  describe "remote_thread_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/thread").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the remote thread path" do
        expect(remote_thread_path(object)).to eq("/remote/objects/42/thread#object-42")
      end
    end

    it "gets the remote thread path" do
      expect(remote_thread_path).to eq("/remote/objects/17/thread#object-17")
    end
  end

  describe "thread_path" do
    let(env) do
      env_factory("GET", "/objects/abc/thread").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the thread path" do
        expect(thread_path(object)).to eq("/objects/xyz/thread#object-42")
      end
    end

    it "gets the thread path" do
      expect(thread_path).to eq("/objects/abc/thread#object-abc")
    end
  end

  describe "edit_object_path" do
    let(env) do
      env_factory("GET", "/objects/abc/edit").tap do |env|
        env.params.url["id"] = "abc"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the edit object path" do
        expect(edit_object_path(object)).to eq("/objects/xyz/edit")
      end
    end

    it "gets the edit object path" do
      expect(edit_object_path).to eq("/objects/abc/edit")
    end
  end

  describe "reply_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/reply").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the reply path" do
        expect(reply_path(object)).to eq("/remote/objects/42/reply")
      end
    end

    it "gets the reply path" do
      expect(reply_path).to eq("/remote/objects/17/reply")
    end
  end

  describe "approve_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/approve").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the approve path" do
        expect(approve_path(object)).to eq("/remote/objects/42/approve")
      end
    end

    it "gets the approve path" do
      expect(approve_path).to eq("/remote/objects/17/approve")
    end
  end

  describe "unapprove_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/unapprove").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the unapprove path" do
        expect(unapprove_path(object)).to eq("/remote/objects/42/unapprove")
      end
    end

    it "gets the unapprove path" do
      expect(unapprove_path).to eq("/remote/objects/17/unapprove")
    end
  end

  describe "block_object_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/block").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the block object path" do
        expect(block_object_path(object)).to eq("/remote/objects/42/block")
      end
    end

    it "gets the block object path" do
      expect(block_object_path).to eq("/remote/objects/17/block")
    end
  end

  describe "unblock_object_path" do
    let(env) do
      env_factory("GET", "/remote/objects/17/unblock").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an object" do
      let(object) { double(:path_double) }

      it "gets the unblock object path" do
        expect(unblock_object_path(object)).to eq("/remote/objects/42/unblock")
      end
    end

    it "gets the unblock object path" do
      expect(unblock_object_path).to eq("/remote/objects/17/unblock")
    end
  end

  describe "remote_actor_path" do
    let(env) do
      env_factory("GET", "/remote/actors/17").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the remote actor path" do
        expect(remote_actor_path(actor)).to eq("/remote/actors/42")
      end
    end

    it "gets the remote actor path" do
      expect(remote_actor_path).to eq("/remote/actors/17")
    end
  end

  describe "actor_path" do
    let(env) do
      env_factory("GET", "/actors/abc").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the actor path" do
        expect(actor_path(actor)).to eq("/actors/xyz")
      end
    end

    it "gets the actor path" do
      expect(actor_path).to eq("/actors/abc")
    end
  end

  describe "block_actor_path" do
    let(env) do
      env_factory("GET", "/remote/actors/17/block").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the block actor path" do
        expect(block_actor_path(actor)).to eq("/remote/actors/42/block")
      end
    end

    it "gets the block actor path" do
      expect(block_actor_path).to eq("/remote/actors/17/block")
    end
  end

  describe "unblock_actor_path" do
    let(env) do
      env_factory("GET", "/remote/actors/17/unblock").tap do |env|
        env.params.url["id"] = "17"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the unblock actor path" do
        expect(unblock_actor_path(actor)).to eq("/remote/actors/42/unblock")
      end
    end

    it "gets the unblock actor path" do
      expect(unblock_actor_path).to eq("/remote/actors/17/unblock")
    end
  end

  describe "actor_relationships_path" do
    let(env) do
      env_factory("GET", "/actors/abc/running").tap do |env|
        env.params.url["username"] = "abc"
        env.params.url["relationship"] = "running"
      end
    end

    context "given an actor and a relationship" do
      let(actor) { double(:path_double) }
      let(relationship) { "helping" }

      it "gets the actor relationships path" do
        expect(actor_relationships_path(actor, relationship)).to eq("/actors/xyz/helping")
      end
    end

    it "gets the actor relationships path" do
      expect(actor_relationships_path).to eq("/actors/abc/running")
    end
  end

  describe "outbox_path" do
    let(env) do
      env_factory("GET", "/actors/abc/outbox").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the outbox path" do
        expect(outbox_path(actor)).to eq("/actors/xyz/outbox")
      end
    end

    it "gets the outbox path" do
      expect(outbox_path).to eq("/actors/abc/outbox")
    end
  end

  describe "inbox_path" do
    let(env) do
      env_factory("GET", "/actors/abc/inbox").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the inbox path" do
        expect(inbox_path(actor)).to eq("/actors/xyz/inbox")
      end
    end

    it "gets the inbox path" do
      expect(inbox_path).to eq("/actors/abc/inbox")
    end
  end

  describe "actor_remote_follow_path" do
    let(env) do
      env_factory("GET", "/actors/abc/remote-follow").tap do |env|
        env.params.url["username"] = "abc"
      end
    end

    context "given an actor" do
      let(actor) { double(:path_double) }

      it "gets the actor remote follow path" do
        expect(actor_remote_follow_path(actor)).to eq("/actors/xyz/remote-follow")
      end
    end

    it "gets the actor remote follow path" do
      expect(actor_remote_follow_path).to eq("/actors/abc/remote-follow")
    end
  end
end
