require "../../src/framework/themes"

require "../spec_helper/base"

Spectator.describe Ktistec::Themes do
  describe ".css_tags" do
    subject { described_class.css_tags }

    context "with no CSS files" do
      before_each { described_class.css_files = [] of String }

      it "returns empty string" do
        expect(subject).to eq("")
      end
    end

    context "with multiple CSS files" do
      before_each { described_class.css_files = ["02-theme.css", "01-base.css", "03-custom.css"] }

      it "generates CSS link tags in sorted order" do
        expected = %(<link rel="stylesheet" href="/themes/01-base.css"/>
<link rel="stylesheet" href="/themes/02-theme.css"/>
<link rel="stylesheet" href="/themes/03-custom.css"/>)
        expect(subject).to eq(expected)
      end
    end

    context "with files containing special characters" do
      before_each { described_class.css_files = ["<script>alert('xss')</script>.css", "file&name.css", %("quoted".css)] }
      it "properly escapes file names" do
        expected = %(<link rel="stylesheet" href="/themes/&quot;quoted&quot;.css"/>
<link rel="stylesheet" href="/themes/&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;.css"/>
<link rel="stylesheet" href="/themes/file&amp;name.css"/>)
        expect(subject).to eq(expected)
      end
    end
  end

  describe ".js_tags" do
    subject { described_class.js_tags }

    context "with no JS files" do
      before_each { described_class.js_files = [] of String }

      it "returns empty string" do
        expect(subject).to eq("")
      end
    end

    context "with multiple JS files" do
      before_each { described_class.js_files = ["02-theme.js", "01-base.js", "03-custom.js"] }

      it "generates script tags in sorted order" do
        expected = %(<script src="/themes/01-base.js"></script>
<script src="/themes/02-theme.js"></script>
<script src="/themes/03-custom.js"></script>)
        expect(subject).to eq(expected)
      end
    end

    context "with files containing special characters" do
      before_each { described_class.js_files = ["<script>alert('xss')</script>.js", "file&name.js", %("quoted".js)] }

      it "properly escapes file names" do
        expected = %(<script src="/themes/&quot;quoted&quot;.js"></script>
<script src="/themes/&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;.js"></script>
<script src="/themes/file&amp;name.js"></script>)
        expect(subject).to eq(expected)
      end
    end
  end
end
