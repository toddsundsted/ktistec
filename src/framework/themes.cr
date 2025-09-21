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
end
