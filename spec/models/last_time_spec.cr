require "../../src/models/last_time"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe LastTime do
  setup_spec

  context "validations" do
    let(account) { register }

    let(options) do
      {
        name: random_string,
        account_id: account.id
      }
    end

    it "rejects blank name" do
      new_last_time = described_class.new(**options.merge({name: ""}))
      expect(new_last_time.valid?).to be_false
      expect(new_last_time.errors.keys).to contain("name")
    end

    it "rejects duplicates" do
      described_class.new(**options).save
      new_last_time = described_class.new(**options)
      expect(new_last_time.valid?).to be_false
      expect(new_last_time.errors.keys).to contain("name")
    end

    it "rejects non-existent account" do
      new_last_time = described_class.new(**options.merge({account_id: 0_i64}))
      expect(new_last_time.valid?).to be_false
      expect(new_last_time.errors.keys).to contain("account")
    end

    it "accepts nil account_id" do
      new_last_time = described_class.new(**options.merge({account_id: nil}))
      expect(new_last_time.valid?).to be_true
    end

    it "successfully validates instance" do
      described_class.new(**options)
    end
  end
end
