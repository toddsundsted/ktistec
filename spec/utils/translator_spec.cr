require "../../src/utils/translator"

require "../spec_helper/base"
require "../spec_helper/network"

Spectator.describe Ktistec::Translator::DeepLTranslator do
  setup_spec

  DEEPL_API = URI.parse("https://api.deepl.com/v2/translate")

  before_each do
    HTTP::Client.cache.set(
      DEEPL_API.resolve("/v2/languages?type=source"),
      [{"language" => "EN", "name" => "English"}, {"language" => "JA", "name" => "Japanese"}],
    )
    HTTP::Client.cache.set(
      DEEPL_API.resolve("/v2/languages?type=target"),
      [{"language" => "FR", "name" => "French"}, {"language": "EN-GB", "name": "British"}, {"language": "EN-US", "name": "American"}],
    )
  end

  it "instantiates the class" do
    expect(described_class.new(DEEPL_API, "")).to be_a(Ktistec::Translator::DeepLTranslator)
  end

  it "requests supported source languages" do
    described_class.new(DEEPL_API, "")
    expect(HTTP::Client.requests).to have("GET https://api.deepl.com/v2/languages?type=source")
  end

  it "requests supported target languages" do
    described_class.new(DEEPL_API, "")
    expect(HTTP::Client.requests).to have("GET https://api.deepl.com/v2/languages?type=target")
  end

  describe "#translate" do
    subject { described_class.new(DEEPL_API, "") }

    it "translates only the name" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "nom"}]})
      expect(subject.translate("name", nil, nil, "en", "fr")).to eq({name: "nom", summary: nil, content: nil})
    end

    it "translates only the summary" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "résumé"}]})
      expect(subject.translate(nil, "summary", nil, "en", "fr")).to eq({name: nil, summary: "résumé", content: nil})
    end

    it "translates only the content" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "contenu"}]})
      expect(subject.translate(nil, nil, "content", "en", "fr")).to eq({name: nil, summary: nil, content: "contenu"})
    end

    macro last_request_body
      JSON.parse(HTTP::Client.requests.last.body.to_s).as_h
    end

    it "sends the language without the variant in the `source_lang` parameter" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "toto"}]})
      subject.translate("foobar", nil, nil, "en-US", "fr")
      expect(last_request_body["source_lang"]).to eq("EN")
    end

    it "does not send the `source_lang` parameter when the source language is not supported" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "toto"}]})
      subject.translate("foobar", nil, nil, "fb", "fr")
      expect(last_request_body.keys).not_to have("source_lang")
    end

    it "sends the language without the variant in the `target_lang` parameter" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "toto"}]})
      subject.translate("foobar", nil, nil, "en", "fr-CA")
      expect(last_request_body["target_lang"]).to eq("FR")
    end

    it "sends the language and variant in the `target_lang` parameter when it has a supported variant" do
      HTTP::Client.cache.set(DEEPL_API, {"translations" => [{"text" => "petrol"}]})
      subject.translate("essence", nil, nil, "fr", "en-GB")
      expect(last_request_body["target_lang"]).to eq("EN-GB")
    end
  end
end

Spectator.describe Ktistec::Translator::LibreTranslateTranslator do
  setup_spec

  LIBRETRANSLATE_API = URI.parse("https://libretranslate.com/translate")

  before_each do
    HTTP::Client.cache.set(
      LIBRETRANSLATE_API.resolve("/languages"),
      [
        {"code" => "en", "name" => "English", "targets" => ["en", "ja", "fr"]},
        {"code" => "ja", "name" => "Japanese", "targets" => ["en", "ja", "fr"]},
        {"code" => "fr", "name" => "French", "targets" => ["en", "ja", "fr"]},
      ],
    )
  end

  it "instantiates the class" do
    expect(described_class.new(LIBRETRANSLATE_API, "")).to be_a(Ktistec::Translator::LibreTranslateTranslator)
  end

  it "requests supported languages" do
    described_class.new(LIBRETRANSLATE_API, "")
    expect(HTTP::Client.requests).to have("GET https://libretranslate.com/languages")
  end

  describe "#translate" do
    subject { described_class.new(LIBRETRANSLATE_API, "") }

    it "translates only the name" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["nom"]})
      expect(subject.translate("name", nil, nil, "en", "fr")).to eq({name: "nom", summary: nil, content: nil})
    end

    it "translates only the summary" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["résumé"]})
      expect(subject.translate(nil, "summary", nil, "en", "fr")).to eq({name: nil, summary: "résumé", content: nil})
    end

    it "translates only the content" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["contenu"]})
      expect(subject.translate(nil, nil, "content", "en", "fr")).to eq({name: nil, summary: nil, content: "contenu"})
    end

    macro last_request_body
      JSON.parse(HTTP::Client.requests.last.body.to_s).as_h
    end

    it "sends the language without the variant in the `source` parameter" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["toto"]})
      subject.translate("foobar", nil, nil, "en-US", "fr")
      expect(last_request_body["source"]).to eq("en")
    end

    it "sends 'auto' in the `source` parameter when the source language is not supported" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["toto"]})
      subject.translate("foobar", nil, nil, "fb", "fr")
      expect(last_request_body["source"]).to eq("auto")
    end

    it "sends the language without the variant in the `target` parameter" do
      HTTP::Client.cache.set(LIBRETRANSLATE_API, {"translatedText" => ["toto"]})
      subject.translate("foobar", nil, nil, "en", "fr-CA")
      expect(last_request_body["target"]).to eq("fr")
    end
  end
end
