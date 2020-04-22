require "../../spec_helper"

class CommonModel
  include Balloon::Model(Common)
end

Spectator.describe Balloon::Model::Common do
  describe ".new" do
    it "includes Balloon::Model::Common" do
      expect(CommonModel.new).to be_a(Balloon::Model::Common)
    end
  end
end
