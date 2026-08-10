require "gemvault/manifest"

RSpec.describe "Gemvault::Manifest serialization" do
  include_context "with a stored foo record"

  describe "round-trip .parse / #to_json" do
    it "preserves identity, checksum, and created_at" do
      expect(Gemvault::Manifest.parse(one_record_manifest.to_json).records).to eq([record])
    end
  end

  describe "#to_h" do
    it "mirrors the on-disk JSON structure with symbol keys", :aggregate_failures do
      manifest_hash = one_record_manifest.to_h
      expect(manifest_hash).to include(vault_version: 2, format: "tarvault", created_at: "t")
      expect(manifest_hash[:gems].first)
        .to include(name: "foo", version: "1.0.0", platform: "ruby", sha256: "abc", encrypted: false)
    end
  end

  describe "StoredGem#matches?" do
    it "is true when the bytes hash to the stored digest" do
      digest = Gemvault::Manifest.digest("data")
      stored = Gemvault::Manifest::StoredGem.new(gem: entry, sha256: digest, encrypted: false)
      expect(stored.matches?("data")).to be(true)
    end

    it "is false when the bytes have changed" do
      expect(record.matches?("tampered")).to be(false)
    end
  end

  describe "#format_version" do
    it "defaults to the current FORMAT_VERSION for a new manifest" do
      expect(empty_manifest.format_version).to eq(2)
    end

    it "reads the declared version from parsed JSON (as an integer)" do
      json = empty_manifest.to_json.sub('"vault_version": 2', '"vault_version": 7')
      expect(Gemvault::Manifest.parse(json).format_version).to eq(7)
    end

    it "tolerates a legacy string vault_version" do
      json = %({"vault_version":"2","format":"tarvault","created_at":"t","gems":[]})
      expect(Gemvault::Manifest.parse(json).format_version).to eq(2)
    end
  end
end
