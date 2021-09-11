require "../../src/views/view_helper"

require "../spec_helper/controller"

Spectator.describe "helper" do
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

    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/#{query}"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

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
        expect(subject.xpath_nodes("//a/@href")).to contain_exactly("/?page=2")
      end
    end

    context "on the second page" do
      let(query) { "?page=2" }

      it "renders the prev link" do
        expect(subject.xpath_nodes("//a/@href")).to contain_exactly("/?page=1")
      end
    end
  end

  describe "authenticity_token" do
    let(env) do
      HTTP::Server::Context.new(
        HTTP::Request.new("GET", "/"),
        HTTP::Server::Response.new(IO::Memory.new)
      )
    end

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
      XML.parse_html(form_tag(model, "/foobar", method: "PUT") { "<div/>" }).document
    end

    it "emits a form with nested content" do
      expect(subject.xpath_nodes("//form/div")).not_to be_empty
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
        XML.parse_html(form_tag(model, "/foobar", data: {"foo" => "bar", "abc" => "xyz"}) { "<div/>" }).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("//form/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(form_tag(nil, "/foobar") { "<div/>" }).document
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("//form/@class")).to contain_exactly("ui form")
      end
    end

    context "given a DELETE method" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", method: "DELETE") { "<div/>" }).document
      end

      it "emits a hidden input" do
        expect(subject.xpath_nodes("//form/input[@type='hidden'][@name='_method']/@value")).to contain_exactly("delete")
      end

      it "sets the method to POST" do
        expect(subject.xpath_nodes("//form/@method")).to contain_exactly("POST")
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
