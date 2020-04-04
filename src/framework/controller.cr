require "kemal"

module Balloon
  module Controller
    macro host
      Balloon.config.host
    end
  end
end

require "../controllers/**"
