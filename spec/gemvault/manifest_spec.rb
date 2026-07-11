require "gemvault/manifest"

RSpec.describe Gemvault::Manifest do
  let(:record) do
    Gemvault::Manifest::Record.new(
      name: "foo",
      version: "1.0.0",
      platform: "ruby",
      created_at: "2026-07-11 00:00:00",
      sha256: "abc",
      encrypted: false,
    )
  end

  describe ".digest" do
    it "returns the SHA256 hexdigest of the bytes" do
      expect(described_class.digest("x")).to eq(OpenSSL::Digest.new("SHA256").hexdigest("x"))
    end
  end

  describe ".empty" do
    it "has no records" do
      expect(described_class.empty(created_at: "t").records).to eq([])
    end
  end

  describe "#with / #without", :aggregate_failures do
    it "adds a record without mutating the original" do
      base = described_class.empty(created_at: "t")
      expect(base.with(record).records).to eq([record])
      expect(base.records).to eq([])
    end

    it "removes the given records" do
      one = described_class.empty(created_at: "t").with(record)
      expect(one.without([record]).records).to eq([])
    end
  end

  describe "#find" do
    it "matches on name, version, and platform" do
      manifest = described_class.empty(created_at: "t").with(record)
      expect(manifest.find("foo", "1.0.0", "ruby")).to eq(record)
    end

    it "returns nil when absent" do
      expect(described_class.empty(created_at: "t").find("x", "1", "ruby")).to be_nil
    end
  end

  describe "#gem_entries" do
    it "maps records to GemEntry objects sorted by name then version" do
      manifest = described_class.empty(created_at: "t").with(record)
      expect(manifest.gem_entries).to eq([record.to_gem_entry])
    end
  end

  describe "round-trip .parse / #to_json" do
    it "preserves records, platform, checksum, and created_at" do
      manifest = described_class.empty(created_at: "t").with(record)
      expect(described_class.parse(manifest.to_json).records).to eq([record])
    end
  end

  describe "#format_version" do
    it "defaults to the current FORMAT_VERSION for a new manifest" do
      expect(described_class.empty(created_at: "t").format_version).to eq(2)
    end

    it "reads the declared version from parsed JSON (as an integer)" do
      json = described_class.empty(created_at: "t").to_json.sub('"vault_version": 2', '"vault_version": 7')
      expect(described_class.parse(json).format_version).to eq(7)
    end

    it "tolerates a legacy string vault_version" do
      json = %({"vault_version":"2","format":"tarvault","created_at":"t","gems":[]})
      expect(described_class.parse(json).format_version).to eq(2)
    end
  end
end
