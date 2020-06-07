require "../spec_helper"

Spectator.describe Balloon::Util do
  describe ".open" do
    it "fetches the specified page" do
      expect(described_class.open("https://external/specified-page").body).to eq("content")
    end

    it "follows redirects" do
      expect(described_class.open("https://external/redirected-page").body).to eq("content")
    end

    it "fails on errors" do
      expect{described_class.open("https://external/returns-500")}.to raise_error(Balloon::Util::OpenError)
    end
  end
end

Spectator.describe Balloon::Util::PaginatedArray do
  subject { Balloon::Util::PaginatedArray{0, 1, 2, 3, 4, 5, 6, 7, 8, 9} }

  describe ".more" do
    it "changes the indicator" do
      expect{subject.more = true}.to change{subject.more?}
    end
  end
end
