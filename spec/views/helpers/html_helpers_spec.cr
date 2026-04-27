require "./support_spec"

Spectator.describe "helpers" do
  setup_spec

  include Ktistec::ViewHelper

  let(model) { ViewHelperSpecSupport::Model.new }

  PARSER_OPTIONS =
    XML::HTMLParserOptions::NOIMPLIED |
      XML::HTMLParserOptions::NODEFDTD

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
      expect(subject.xpath_nodes("/form/input[@name='visibility']/@value")).to contain_exactly("public")
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
      XML.parse_html(form_button("/foobar", method: "PUT", form_id: "woof", form_class: "blarg", button_id: "beep", button_class: "honk", csrf: "CSRF") { "<div/>" }, PARSER_OPTIONS).document
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

    it "specifies the form id " do
      expect(subject.xpath_nodes("/form/@id")).to contain_exactly("woof")
    end

    it "specifies the form class" do
      expect(subject.xpath_nodes("/form/@class")).to contain_exactly("blarg")
    end

    it "specifies the button id" do
      expect(subject.xpath_nodes("/form/button/@id")).to contain_exactly("beep")
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
    let(env) { make_env("GET", "/") }

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

    context "given an error value containing HTML" do
      before_each { model.errors = {"field" => [%[<img src=x onerror="alert(1)">]]} }

      it "renders the value as text" do
        expect(subject.xpath_nodes("/div/div/text()")).to contain_exactly(%[field <img src=x onerror="alert(1)">])
      end

      it "does not produce an img element" do
        expect(subject.xpath_nodes("//img")).to be_empty
      end
    end

    context "given an error key containing HTML" do
      before_each { model.errors = { %[field"><script>alert(1)</script>] => ["is wrong"] } }

      it "renders the key as text" do
        expect(subject.xpath_nodes("/div/div/text()")).to contain_exactly(%[field"><script>alert(1)</script> is wrong])
      end

      it "does not produce a script element" do
        expect(subject.xpath_nodes("//script")).to be_empty
      end
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

    context "when specifying form data" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", form: "data", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "sets the enctype" do
        expect(subject.xpath_nodes("/form/@enctype")).to contain_exactly("multipart/form-data")
      end
    end

    context "when specifying form urlencoded" do
      subject do
        XML.parse_html(form_tag(model, "/foobar", form: "urlencoded", csrf: nil) { "<div/>" }, PARSER_OPTIONS).document
      end

      it "sets the enctype" do
        expect(subject.xpath_nodes("/form/@enctype")).to contain_exactly("application/x-www-form-urlencoded")
      end
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
      XML.parse_html(input_tag("Label", model, field, id: "woof", class: "blarg", type: "foobar", placeholder: "quoz"), PARSER_OPTIONS).document
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

    it "specifies the id" do
      expect(subject.xpath_nodes("/div/input/@id")).to contain_exactly("woof")
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

    context "given autofocus" do
      subject do
        XML.parse_html(input_tag("Label", model, field, autofocus: true), PARSER_OPTIONS).document
      end

      it "specifies the autofocus attribute" do
        expect(subject.xpath_nodes("/div/input/@autofocus")).not_to be_empty
      end
    end
  end

  describe "textarea_tag" do
    subject do
      XML.parse_html(textarea_tag("Label", model, :field, id: "woof", class: "blarg", rows: 4, placeholder: "quoz"), PARSER_OPTIONS).document
    end

    it "emits div containing label and textarea tags" do
      expect(subject.xpath_nodes("/div[label][textarea]")).not_to be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("/div/label/text()")).to contain_exactly("Label")
    end

    it "emits a textarea tag with the specified name" do
      expect(subject.xpath_nodes("/div/textarea/@name")).to contain_exactly("field")
    end

    it "emits a textarea tag with the associated text" do
      expect(subject.xpath_nodes("/div/textarea/text()")).to contain_exactly("Value")
    end

    it "specifies the id" do
      expect(subject.xpath_nodes("/div/textarea/@id")).to contain_exactly("woof")
    end

    it "specifies the class" do
      expect(subject.xpath_nodes("/div/textarea/@class")).to contain_exactly("blarg")
    end

    it "overrides the default rows" do
      expect(subject.xpath_nodes("/div/textarea/@rows")).to contain_exactly("4")
    end

    it "specifies the placeholder" do
      expect(subject.xpath_nodes("/div/textarea/@placeholder")).to contain_exactly("quoz")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field error")
    end

    context "given data attributes" do
      subject do
        XML.parse_html(textarea_tag("Label", model, :field, data: {"foo" => "bar", "abc" => "xyz"}), PARSER_OPTIONS).document
      end

      it "emits data attributes" do
        expect(subject.xpath_nodes("/div/textarea/@*[starts-with(name(),'data-')]")).to contain_exactly("bar", "xyz")
      end
    end

    context "given a nil model" do
      subject do
        XML.parse_html(textarea_tag("Label", nil, :field), PARSER_OPTIONS).document
      end

      it "emits a textarea tag with the specified name" do
        expect(subject.xpath_nodes("/div/textarea/@name")).to contain_exactly("field")
      end

      it "does not set the error class" do
        expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field")
      end
    end

    context "given a value with HTML characters" do
      before_each do
        model.field = %q|Value with <tags> & "quotes".|
      end

      it "emits a textarea tag with the associated value" do
        expect(subject.xpath_nodes("/div/textarea/text()")).to contain_exactly(%q|Value with <tags> & "quotes".|)
      end
    end

    context "given autofocus" do
      subject do
        XML.parse_html(textarea_tag("Label", model, :field, autofocus: true), PARSER_OPTIONS).document
      end

      it "specifies the autofocus attribute" do
        expect(subject.xpath_nodes("/div/textarea/@autofocus")).not_to be_empty
      end
    end
  end

  describe "select_tag" do
    subject do
      XML.parse_html(select_tag("Label", model, field, {one: "One", two: "Two"}, id: "woof", class: "blarg"), PARSER_OPTIONS).document
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

    it "specifies the id" do
      expect(subject.xpath_nodes("/div/select/@id")).to contain_exactly("woof")
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

  describe "trix_editor" do
    subject do
      XML.parse_html(trix_editor("Label", model, field, id: "woof", class: "blarg"), PARSER_OPTIONS).document
    end

    it "emits div containing label, trix-editor and textarea tags" do
      expect(subject.xpath_nodes("/div[label][trix-editor][textarea]")).not_to be_empty
    end

    it "includes data-turbo-permanent on field" do
      expect(subject.xpath_nodes("/div/@data-turbo-permanent")).to_not be_empty
    end

    it "emits a label tag with the label text" do
      expect(subject.xpath_nodes("/div/label/text()")).to contain_exactly("Label")
    end

    it "emits a trix-editor with the specified input attribute" do
      expect(subject.xpath_nodes("/div/trix-editor/@input")).to contain_exactly("woof")
    end

    it "specifies the custom class on trix-editor" do
      expect(subject.xpath_nodes("/div/trix-editor/@class")).to contain_exactly("blarg")
    end

    it "emits a textarea with the associated value" do
      expect(subject.xpath_nodes("/div/textarea/text()")).to contain_exactly("Value")
    end

    it "emits a textarea with the specified id" do
      expect(subject.xpath_nodes("/div/textarea/@id")).to contain_exactly("woof")
    end

    it "emits a textarea with the specified name" do
      expect(subject.xpath_nodes("/div/textarea/@name")).to contain_exactly("field")
    end

    it "sets the error class" do
      expect(subject.xpath_nodes("/div/@class")).to contain_exactly("field error")
    end

    context "given a nil model" do
      subject do
        XML.parse_html(trix_editor("Label", nil, field), PARSER_OPTIONS).document
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

  describe "params_to_inputs" do
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

  describe ".number_to_word" do
    it "returns 'one'" do
      expect(Ktistec::ViewHelper.number_to_word(1)).to eq("one")
    end

    it "returns 'ten'" do
      expect(Ktistec::ViewHelper.number_to_word(10)).to eq("ten")
    end

    it "returns 'twenty'" do
      expect(Ktistec::ViewHelper.number_to_word(20)).to eq("twenty")
    end

    it "returns the number as a string for values over 20" do
      expect(Ktistec::ViewHelper.number_to_word(21)).to eq("21")
    end

    it "returns the number as a string for negative values" do
      expect(Ktistec::ViewHelper.number_to_word(-5)).to eq("-5")
    end
  end
end
