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

  ## HTML helpers

  describe "paginate" do
    let(query) { "" }

    let(env) { env_factory("GET", "/#{query}") }

    let(collection) { Ktistec::Util::PaginatedArray(Int32).new }

    subject do
      XML.parse_html(self.class.paginate(env, collection)).document
    end

    it "does not render pagination controls" do
      expect(subject.xpath_nodes("//a")).to be_empty
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

  describe "activity_button" do
    subject do
      XML.parse_html(activity_button("/foobar", "https://object", "Zap", method: "PUT", form_class: "blarg", button_class: "honk", csrf: "CSRF") { "<div/>" }).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("//form/button/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("//form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "emits a form with a hidden input specifying the object" do
      expect(subject.xpath_nodes("//form/input[@name='object']/@value")).to contain_exactly("https://object")
    end

    it "emits a form with a hidden input specifying the type" do
      expect(subject.xpath_nodes("//form/input[@name='type']/@value")).to contain_exactly("Zap")
    end

    it "emits a form with a hidden input specifying the visibility" do
      expect(subject.xpath_nodes("//form/input[@name='public']/@value")).to contain_exactly("1")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("//form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("//form/@method")).to contain_exactly("PUT")
    end

    it "specifies the form class" do
      expect(subject.xpath_nodes("//form/@class")).to contain_exactly("blarg")
    end

    it "specifies the button class" do
      expect(subject.xpath_nodes("//form/button/@class")).to contain_exactly("honk")
    end

    context "without a body" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", csrf: nil)).document
      end

      it "emits a form with nested content" do
        expect(subject.xpath_nodes("//form/button/text()")).to contain_exactly("Label")
      end
    end

    context "given data attributes" do
      subject do
        XML.parse_html(activity_button("Label", "/foobar", "https://object", form_data: {"foo" => "bar", "abc" => "xyz"}, button_data: {"one" => "1", "two" => "2"}, csrf: nil)).document
      end

      it "emits form data attributes" do
        expect(subject.xpath_nodes("//form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end

      it "emits button data attributes" do
        expect(subject.xpath_nodes("//form/button/@*[starts-with(name(),'data-')]")).to contain_exactly("1", "2")
      end
    end
  end

  describe "form_button" do
    subject do
      XML.parse_html(form_button("/foobar", method: "PUT", form_class: "blarg", button_class: "honk", csrf: "CSRF") { "<div/>" }).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("//form/button/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("//form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("//form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("//form/@method")).to contain_exactly("PUT")
    end

    it "specifies the form class" do
      expect(subject.xpath_nodes("//form/@class")).to contain_exactly("blarg")
    end

    it "specifies the button class" do
      expect(subject.xpath_nodes("//form/button/@class")).to contain_exactly("honk")
    end

    context "without a body" do
      subject do
        XML.parse_html(form_button("Label", "/foobar", csrf: nil)).document
      end

      it "emits a form with nested content" do
        expect(subject.xpath_nodes("//form/button/text()")).to contain_exactly("Label")
      end
    end

    context "given data attributes" do
      subject do
        XML.parse_html(form_button("Label", "/foobar", form_data: {"foo" => "bar", "abc" => "xyz"}, button_data: {"one" => "1", "two" => "2"}, csrf: nil)).document
      end

      it "emits form data attributes" do
        expect(subject.xpath_nodes("//form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end

      it "emits button data attributes" do
        expect(subject.xpath_nodes("//form/button/@*[starts-with(name(),'data-')]")).to contain_exactly("1", "2")
      end
    end
  end

  describe "authenticity_token" do
    let(env) { env_factory("GET", "/") }

    subject do
      XML.parse_html(authenticity_token(env)).document
    end

    before_each { env.session.string("csrf", "TOKEN") }

    it "emits input tag with the authenticity token" do
      expect(subject.xpath_nodes("//input[@type='hidden'][@name='authenticity_token']/@value")).to have("TOKEN")
    end
  end

  describe "error_messages" do
    subject do
      XML.parse_html(error_messages(model)).document
    end

    it "emits nested div containing error message" do
      expect(subject.xpath_nodes("//div/div/text()")).to contain_exactly("field is wrong")
    end
  end

  describe "form_tag" do
    subject do
      XML.parse_html(form_tag(model, "/foobar", method: "PUT", csrf: "CSRF") { "<div/>" }).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("//form/div")).not_to be_empty
    end

    it "emits a form with a csrf token" do
      expect(subject.xpath_nodes("//form/input[@name='authenticity_token']/@value")).to contain_exactly("CSRF")
    end

    it "specifies the action" do
      expect(subject.xpath_nodes("//form/@action")).to contain_exactly("/foobar")
    end

    it "specifies the method" do
      expect(subject.xpath_nodes("//form/@method")).to contain_exactly("PUT")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("//form/@class")).to contain_exactly("ui form error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", data: {"foo" => "bar", "abc" => "xyz"}, csrf: nil) { "<div/>" }).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("//form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(form_tag(nil, "/foobar", csrf: nil) { "<div/>" }).document
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("//form/@class")).to contain_exactly("ui form")
      end
    end

    context "given a DELETE method" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", method: "DELETE", csrf: nil) { "<div/>" }).document
      end

      it "emits a hidden input" do
        expect(subject.xpath_nodes("//form/input[@type='hidden'][@name='_method']/@value")).to contain_exactly("delete")
      end

      it "sets the method to POST" do
        expect(subject.xpath_nodes("//form/@method")).to contain_exactly("POST")
      end
    end

    context "given a GET method" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", method: "GET", csrf: "CSRF") { "<div/>" }).document
      end

      it "does not emit a csrf token" do
        expect(subject.xpath_nodes("//form/input[@name='authenticity_token']")).to be_empty
      end

      it "sets the method to GET" do
        expect(subject.xpath_nodes("//form/@method")).to contain_exactly("GET")
      end
    end
  end

  describe "input_tag" do
    subject do
      XML.parse_html(input_tag("Label", model, field, class: "blarg", type: "foobar", placeholder: "quoz")).document
    end

    it "emits div containing label and input tags" do
      expect(subject.xpath_nodes("//div[label][input]")).not_to be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("//div/label/text()")).to contain_exactly("Label")
    end

    it "emits an input tag with the specified name" do
      expect(subject.xpath_nodes("//div/input/@name")).to contain_exactly("field")
    end

    it "emits an input tag with the associated value" do
      expect(subject.xpath_nodes("//div/input/@value")).to contain_exactly("Value")
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("//div/input/@class")).to contain_exactly("blarg")
    end

    it "overrides the default type" do
      expect(subject.xpath_nodes("//div/input/@type")).to contain_exactly("foobar")
    end

    it "specifies the placeholder" do
      expect(subject.xpath_nodes("//div/input/@placeholder")).to contain_exactly("quoz")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("//div/@class")).to contain_exactly("field error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(input_tag("Label", model, field, data: {"foo" => "bar", "abc" => "xyz"})).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("//div/input/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(input_tag("Label", nil, field)).document
      end

      it "emits an input tag with the specified name" do
        expect(subject.xpath_nodes("//div/input/@name")).to contain_exactly("field")
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("//div/@class")).to contain_exactly("field")
      end
    end

    context "given a value with an ampersand and quotes" do
      before_each do
        model.field = %q|Value with ampersand & "quotes".|
      end

      it "emits an input tag with the associated value" do
        expect(subject.xpath_nodes("//div/input/@value")).to contain_exactly(%q|Value with ampersand & "quotes".|)
      end
    end
  end

  describe "select_tag" do
    subject do
      XML.parse_html(select_tag("Label", model, field, {one: "One", two: "Two"}, class: "blarg")).document
    end

    it "emits div containing label and select tags" do
      expect(subject.xpath_nodes("//div[label][select]")).not_to be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("//div/label/text()")).to contain_exactly("Label")
    end

    it "emits a select tag with the specified name" do
      expect(subject.xpath_nodes("//div/select/@name")).to contain_exactly("field")
    end

    it "emits option tags with the specified values" do
      expect(subject.xpath_nodes("//div/select/option/@value")).to contain_exactly("one", "two")
    end

    it "emits option tags with the specified text" do
      expect(subject.xpath_nodes("//div/select/option/text()")).to contain_exactly("One", "Two")
    end

    context "given a field value that matches an option" do
      before_each { model.field = "one" }

      it "emits an option tag with the option selected" do
        expect(subject.xpath_nodes("//div/select/option[@selected]/text()")).to contain_exactly("One")
      end
    end

    context "given a selected value that matches an option" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"}, selected: :two)).document
      end

      it "emits an option tag with the option selected" do
        expect(subject.xpath_nodes("//div/select/option[@selected]/text()")).to contain_exactly("Two")
      end
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("//div/select/@class")).to contain_exactly("blarg")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("//div/@class")).to contain_exactly("field error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"}, data: {"foo" => "bar", "abc" => "xyz"})).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("//div/select/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(select_tag("Label", nil, field, {one: "One", two: "Two"})).document
      end

      it "emits a select tag with the specified name" do
        expect(subject.xpath_nodes("//div/select/@name")).to contain_exactly("field")
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("//div/@class")).to contain_exactly("field")
      end
    end
  end

  ## JSON helpers

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
end
