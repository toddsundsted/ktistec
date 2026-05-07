require "./spec_helper"

Spectator.describe Slang::Runtime do
  let(io) { IO::Memory.new }

  describe ".emit" do
    it "emits SafeHTML raw" do
      described_class.emit(io, Ktistec::SafeHTML.assert_safe("<em>bold</em>"))
      expect(io.to_s).to eq("<em>bold</em>")
    end

    it "HTML-escapes a plain String" do
      described_class.emit(io, "<em>bold</em>")
      expect(io.to_s).to eq("&lt;em&gt;bold&lt;/em&gt;")
    end

    it "HTML-escapes the result of .to_s on non-string values" do
      described_class.emit(io, [1, "<a>"])
      expect(io.to_s).to eq("[1, &quot;&lt;a&gt;&quot;]")
    end

    it "emits empty string for nil" do
      described_class.emit(io, nil)
      expect(io.to_s).to eq("")
    end
  end

  describe ".emit_comment" do
    it "HTML-escapes a plain String" do
      described_class.emit_comment(io, %(<script>alert("x")</script>))
      expect(io.to_s).to eq("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
    end

    it "HTML-escapes a SafeHTML" do
      described_class.emit_comment(io, Ktistec::SafeHTML.assert_safe("<em>x</em>"))
      expect(io.to_s).to eq("&lt;em&gt;x&lt;/em&gt;")
    end

    it "breaks `--` to prevent comment early-close" do
      described_class.emit_comment(io, "a -- b")
      expect(io.to_s).to eq("a -&#45; b")
    end

    it "breaks consecutive runs of `-`" do
      described_class.emit_comment(io, "a---b----c")
      expect(io.to_s).to eq("a-&#45;-b-&#45;-&#45;c")
    end

    it "leaves `-` alone" do
      described_class.emit_comment(io, "a-b-c")
      expect(io.to_s).to eq("a-b-c")
    end

    it "emits empty string for nil" do
      described_class.emit_comment(io, nil)
      expect(io.to_s).to eq("")
    end
  end

  describe ".emit_attr" do
    it "emits a SafeAttrValue raw" do
      described_class.emit_attr(io, "title", Ktistec::SafeAttrValue.assert_safe(%(He said &quot;hi&quot;)))
      expect(io.to_s).to eq(%( title="He said &quot;hi&quot;"))
    end

    it "HTML-escapes a plain String" do
      described_class.emit_attr(io, "title", %(He said "hi"))
      expect(io.to_s).to eq(%( title="He said &quot;hi&quot;"))
    end

    it "HTML-escapes a SafeHTML" do
      described_class.emit_attr(io, "title", Ktistec::SafeHTML.assert_safe("<em>x</em>"))
      expect(io.to_s).to eq(%( title="&lt;em&gt;x&lt;/em&gt;"))
    end

    it "emits name for true" do
      described_class.emit_attr(io, "checked", true)
      expect(io.to_s).to eq(" checked")
    end

    it "omits for false" do
      described_class.emit_attr(io, "checked", false)
      expect(io.to_s).to eq("")
    end

    it "HTML-escapes the result of .to_s on non-string values" do
      described_class.emit_attr(io, "data-x", [1, "<a>"])
      expect(io.to_s).to eq(%( data-x="[1, &quot;&lt;a&gt;&quot;]"))
    end
  end

  describe ".emit_url_attr" do
    it "emits a SafeURI raw" do
      described_class.emit_url_attr(io, "href", Ktistec::SafeURI.assert_safe("/x"))
      expect(io.to_s).to eq(%( href="/x"))
    end

    it "HTML-escapes the URL" do
      described_class.emit_url_attr(io, "href", Ktistec::SafeURI.assert_safe("/x?a=1&b=2"))
      expect(io.to_s).to eq(%( href="/x?a=1&amp;b=2"))
    end

    it "skips emission for nil" do
      described_class.emit_url_attr(io, "href", nil.as(Ktistec::SafeURI?))
      expect(io.to_s).to eq("")
    end
  end

  describe ".emit_splat_attrs" do
    it "emits non-URL keys" do
      described_class.emit_splat_attrs(io, {"title" => "x"}, false)
      expect(io.to_s).to eq(%( title="x"))
    end

    it "skips nil values" do
      described_class.emit_splat_attrs(io, {"title" => nil}, false)
      expect(io.to_s).to eq("")
    end

    it "skips the class key when skip_class is true" do
      described_class.emit_splat_attrs(io, {"class" => "x"}, true)
      expect(io.to_s).to eq("")
    end

    it "emits the class key when skip_class is false" do
      described_class.emit_splat_attrs(io, {"class" => "x"}, false)
      expect(io.to_s).to eq(%( class="x"))
    end

    context "URL-attribute keys" do
      it "emits a SafeURI raw" do
        described_class.emit_splat_attrs(io, {"href" => Ktistec::SafeURI.assert_safe("/x")}, false)
        expect(io.to_s).to eq(%( href="/x"))
      end

      it "raises when value is a plain String" do
        expect { described_class.emit_splat_attrs(io, {"href" => "/x"}, false) }.to \
          raise_error(ArgumentError, /URL attribute `href` requires SafeURI/)
      end

      it "raises when value is a non-SafeURI type" do
        expect { described_class.emit_splat_attrs(io, {"src" => 42}, false) }.to \
          raise_error(ArgumentError, /URL attribute `src` requires SafeURI/)
      end

      it "is case-insensitive" do
        expect { described_class.emit_splat_attrs(io, {"HREF" => "/x"}, false) }.to \
          raise_error(ArgumentError, /URL attribute `HREF` requires SafeURI/)
      end
    end

    context "event-handler keys" do
      it "raises on `onclick`" do
        expect { described_class.emit_splat_attrs(io, {"onclick" => "alert(1)"}, false) }.to \
          raise_error(ArgumentError, /event-handler attribute `onclick`/)
      end

      it "is case-insensitive" do
        expect { described_class.emit_splat_attrs(io, {"OnClick" => "x"}, false) }.to \
          raise_error(ArgumentError, /event-handler attribute `OnClick`/)
      end
    end
  end
end
