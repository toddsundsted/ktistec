require "file_utils"

require "../../src/controllers/home"
require "../../src/framework/themes"

require "../spec_helper/controller"

Spectator.describe "Themes Integration" do
  setup_spec

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
    Ktistec::Themes.css_files = [] of String
    Ktistec::Themes.js_files = [] of String
  end

  after_each do
    FileUtils.rm_rf(tmp_dir) if Dir.exists?(tmp_dir)
  end

  it "discovers theme files and includes them in layout" do
    File.write(File.join(themes_dir, "02-theme.css"), "/* theme styles */")
    File.write(File.join(themes_dir, "01-base.css"), "/* base styles */")
    File.write(File.join(themes_dir, "theme.js"), "// theme script")
    File.write(File.join(themes_dir, "ignored.txt"), "ignored file")

    # simulate server startup
    Ktistec::Themes.discover_files(tmp_dir)

    get "/", HTTP::Headers{"Accept" => "text/html"}

    expect(response.status_code).to eq(200)
    html = response.body

    expect(html).to contain(%(<link rel="stylesheet" href="/themes/01-base.css"/>))
    expect(html).to contain(%(<link rel="stylesheet" href="/themes/02-theme.css"/>))
    expect(html).to contain(%(<script src="/themes/theme.js"></script>))
    expect(html).not_to contain("ignored.txt")

    site_css_pos = html.index!(%(<link rel="stylesheet" href="/dist/site.css"/>))
    site_js_pos = html.index!(%(<script src="/dist/site.bundle.js"></script>))

    css1_pos = html.index!("01-base.css")
    css2_pos = html.index!("02-theme.css")
    js_pos = html.index!("theme.js")

    expect(site_css_pos).to be < css1_pos
    expect(site_js_pos).to be < js_pos

    expect(css1_pos).to be < css2_pos
    expect(css2_pos).to be < js_pos
  end
end
