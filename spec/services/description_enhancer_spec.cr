require "../../src/services/description_enhancer"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe Ktistec::DescriptionEnhancer do
  setup_spec

  before_each { Ktistec::DescriptionEnhancer.clear_cache! }

  after_each { Ktistec.set_default_settings }

  describe ".enhanced_description" do
    context "when description is nil" do
      before_each { Ktistec.settings.assign({"description" => nil}) }

      it "returns empty string" do
        expect(Ktistec::DescriptionEnhancer.enhanced_description).to be_nil
      end
    end

    context "when description is blank" do
      before_each { Ktistec.settings.assign({"description" => ""}) }

      it "returns empty string" do
        expect(Ktistec::DescriptionEnhancer.enhanced_description).to be_nil
      end
    end

    context "with valid description" do
      before_each do
        Ktistec.settings.assign({
          "description" => "<p>#hashtag</p><script>alert('xss')</script><img src='src' onerror='alert(1)'>"
        })
      end

      it "enhances and sanitizes content" do
        result = Ktistec::DescriptionEnhancer.enhanced_description
        expect(result).to eq("<p><a href='https://test.test/tags/hashtag' data-turbo-frame='_top'>#hashtag</a></p><img src='src' class='ui image' loading='lazy'>")
      end
    end

    context "caching behavior" do
      before_each do
        Ktistec.settings.assign({"description" => "<p>Cached content</p>"})
      end

      it "caches the result" do
        first_result = Ktistec::DescriptionEnhancer.enhanced_description

        second_result = Ktistec::DescriptionEnhancer.enhanced_description

        expect(second_result).to be(first_result)
      end

      it "recomputes when assigned" do
        description = "<p>Cached content</p>"

        Ktistec.settings.assign({"description" => description})

        first_result = Ktistec::DescriptionEnhancer.enhanced_description
        expect(first_result).to eq("<p>Cached content</p>")

        # intentially reassign same content to test cache invalidation
        Ktistec.settings.assign({"description" => description})

        second_result = Ktistec::DescriptionEnhancer.enhanced_description
        expect(second_result).to eq("<p>Cached content</p>")

        expect(second_result).not_to be(first_result)
      end
    end
  end
end
