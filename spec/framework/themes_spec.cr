require "file_utils"

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

  describe ".discover_files" do
    let(tmp_dir) do
      File.join(Dir.tempdir, "themes_#{Random.new.rand(10000)}").tap do |tmp_dir|
        Dir.mkdir(tmp_dir)
      end
    end

    let(themes_dir) do
      File.join(tmp_dir, "themes").tap do |themes_dir|
        Dir.mkdir(themes_dir)
      end
    end

    before_each do
      described_class.css_files = [] of String
      described_class.js_files = [] of String
    end

    after_each do
      FileUtils.rm_rf(tmp_dir) if Dir.exists?(tmp_dir)
    end

    it "handles missing themes directory gracefully" do
      described_class.discover_files(tmp_dir)

      expect(described_class.css_files).to be_empty
      expect(described_class.js_files).to be_empty
    end

    it "discovers CSS and JS files in themes directory" do
      File.write(File.join(themes_dir, "02-style.css"), "/* style */")
      File.write(File.join(themes_dir, "01-base.css"), "/* base */")
      File.write(File.join(themes_dir, "script.js"), "// js")
      File.write(File.join(themes_dir, "README.txt"), "ignored")

      described_class.discover_files(tmp_dir)

      expect(described_class.css_files).to contain_exactly("01-base.css", "02-style.css")
      expect(described_class.js_files).to contain_exactly("script.js")
    end

    it "clears existing files before discovery" do
      described_class.css_files = ["old.css"]
      described_class.js_files = ["old.js"]

      File.write(File.join(themes_dir, "new.css"), "/* new */")

      described_class.discover_files(tmp_dir)

      expect(described_class.css_files).to contain_exactly("new.css")
      expect(described_class.js_files).to be_empty
    end
  end
end
