require "../../spec_helper/controller"
require "../../spec_helper/factory"

module ViewHelperSpecSupport
  class Model
    property field = "Value"
    getter errors = {"field" => ["is wrong"]}
  end
end
