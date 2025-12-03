require "../../src/utils/emoji"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Ktistec::Emoji do
  setup_spec

  describe ".emojify" do
    it "returns content unchanged" do
      content = "hello :wave: world"
      expect(described_class.emojify(content, [] of Tag::Emoji)).to eq(content)
    end

    let_build(:emoji, named: coffee, name: "coffee", href: "https://example.com/coffee.png")
    let_build(:emoji, named: wave, name: "wave", href: "https://example.com/wave.png")

    it "replaces different emoji" do
      content = "good morning :coffee: :wave:"
      emoji = [coffee, wave]
      result = described_class.emojify(content, emoji)
      expect(result).to contain(%(<img src="https://example.com/coffee.png" class="emoji" alt=":coffee:" title=":coffee:">))
      expect(result).to contain(%(<img src="https://example.com/wave.png" class="emoji" alt=":wave:" title=":wave:">))
    end

    it "replaces repeated emoji" do
      content = ":wave: :wave: :wave:"
      emoji = [wave]
      result = described_class.emojify(content, emoji)
      expected = %(<img src="https://example.com/wave.png" class="emoji" alt=":wave:" title=":wave:">)
      expect(result).to eq("#{expected} #{expected} #{expected}")
    end

    it "leaves unknown emoji unchanged" do
      content = "Hello :unknown: :wave:"
      emoji = [wave]
      result = described_class.emojify(content, emoji)
      expect(result).not_to contain(%(<img src="https://example.com/unknown.png" class="emoji" alt=":unknown:" title=":unknown:">))
      expect(result).to contain(%(<img src="https://example.com/wave.png" class="emoji" alt=":wave:" title=":wave:">))
    end

    let_build(:emoji, named: batman_upper, name: "Batman", href: "https://example.com/Batman.png")
    let_build(:emoji, named: batman_lower, name: "batman", href: "https://example.com/batman.png")

    it "handles case-sensitive emoji" do
      content = "I love :Batman: and :batman:"
      emoji = [batman_upper, batman_lower]
      result = described_class.emojify(content, emoji)
      expect(result).to contain(%(<img src="https://example.com/Batman.png" class="emoji" alt=":Batman:" title=":Batman:">))
      expect(result).to contain(%(<img src="https://example.com/batman.png" class="emoji" alt=":batman:" title=":batman:">))
    end

    it "handles emoji in HTML text" do
      content = "<p>hello :wave: world</p>"
      emoji = [wave]
      result = described_class.emojify(content, emoji)
      expect(result).to eq(%(<p>hello <img src="https://example.com/wave.png" class="emoji" alt=":wave:" title=":wave:"> world</p>))
    end

    it "ignores emoji in HTML attributes" do
      content = %(<a href="https://example.com/:wave:">:wave:</a>)
      emoji = [wave]
      result = described_class.emojify(content, emoji)
      expect(result).to eq(%(<a href="https://example.com/:wave:"><img src="https://example.com/wave.png" class="emoji" alt=":wave:" title=":wave:"></a>))
    end
  end
end
