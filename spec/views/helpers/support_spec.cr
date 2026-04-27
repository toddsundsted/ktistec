require "../../spec_helper/controller"
require "../../spec_helper/factory"

module ViewHelperSpecSupport
  class Model
    property field = "Value"
    property errors = {"field" => ["is wrong"]}
  end
end
