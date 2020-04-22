require "../../spec_helper"

class CommonModel
  include Balloon::Model(Common)
end

Spectator.describe Balloon::Model::Common do
  before_each do
    Balloon.database.exec <<-SQL
      CREATE TABLE common_models (
        id integer PRIMARY KEY AUTOINCREMENT,
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL
      )
    SQL
  end
  after_each do
    Balloon.database.exec "DROP TABLE common_models"
  end

  describe ".new" do
    it "includes Balloon::Model::Common" do
      expect(CommonModel.new).to be_a(Balloon::Model::Common)
    end
  end

  context "timestamps" do
    let(common) { CommonModel.new.save }

    it "sets created_at" do
      expect(common.created_at).not_to be_nil
    end

    it "sets updated_at" do
      expect(common.updated_at).not_to be_nil
    end

    it "does not change created_at" do
      expect{common.save}.not_to change{common.created_at}
    end

    it "changes updated_at" do
      expect{common.save}.to change{common.updated_at}
    end
  end
end
