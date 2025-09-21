require "html"

module Ktistec::Themes
  class_property css_files = [] of String
  class_property js_files = [] of String

  def self.css_tags
    css_files.sort.map do |file|
      %(<link rel="stylesheet" href="/themes/#{::HTML.escape(file)}"/>)
    end.join("\n")
  end

  def self.js_tags
    js_files.sort.map do |file|
      %(<script src="/themes/#{::HTML.escape(file)}"></script>)
    end.join("\n")
  end

  # Discovers files in the public/themes directory and caches them.
  #
  def self.discover_files(public_folder = "public", themes_folder = "themes")
    themes_path = File.join(public_folder, themes_folder)
    return unless Dir.exists?(themes_path)

    css_files.clear
    js_files.clear

    Dir.glob(File.join(themes_path, "*.{css,js}")).sort.each do |path|
      filename = File.basename(path)
      case File.extname(filename)
      when ".css"
        css_files << filename
      when ".js"
        js_files << filename
      end
    end
  end
end
