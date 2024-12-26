require "../../src/utils/translator"

require "../spec_helper/base"
require "../spec_helper/network"

Spectator.describe Ktistec::Translator::DeepLTranslator do
  setup_spec

  DEEPL_API = URI.parse("https://api.deepl.com/v2/translate")

  it "instantiates the class" do
    expect(described_class.new(DEEPL_API, "")).to be_a(Ktistec::Translator::DeepLTranslator)
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
  end
end

Spectator.describe Ktistec::Translator::LibreTranslateTranslator do
  setup_spec

  LIBRETRANSLATE_API = URI.parse("https://libretranslate.com/translate")

  it "instantiates the class" do
    expect(described_class.new(LIBRETRANSLATE_API, "")).to be_a(Ktistec::Translator::LibreTranslateTranslator)
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
  end
end
