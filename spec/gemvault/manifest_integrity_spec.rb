require "gemvault/manifest"

RSpec.describe "Gemvault::Manifest integrity" do
  include_context "with a stored foo record"

  describe "StoredGem#matches?" do
    it "is true when the bytes hash to the stored digest" do
      stored = Gemvault::Manifest::StoredGem.new(gem: entry, sha256: Gemvault::Manifest.digest("data"),
                                                 encrypted: false)
      expect(stored.matches?("data")).to be(true)
    end

    it "is false when the bytes have changed" do
      expect(record.matches?("tampered")).to be(false)
    end
  end

  describe "#format_version" do
    it "defaults to the current FORMAT_VERSION for a new manifest" do
      expect(empty_manifest.format_version).to eq(3)
    end

    it "carries a version the running gemvault does not write" do
      expect(Gemvault::Manifest.new(created_at: stamp, records: [], format_version: 9).format_version).to eq(9)
    end
  end
end
