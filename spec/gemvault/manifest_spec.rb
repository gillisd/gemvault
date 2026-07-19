require "gemvault/manifest"
require "gemvault/gem_reference"

RSpec.describe Gemvault::Manifest do
  let(:entry) do
    Gemvault::GemEntry.new(
      name: "foo", version: "1.0.0", platform: "ruby", created_at: "2026-07-11 00:00:00",
    )
  end

  let(:record) do
    Gemvault::Manifest::StoredGem.new(gem: entry, sha256: "abc", encrypted: false)
  end

  describe ".digest" do
    it "returns the SHA256 hexdigest of the bytes" do
      expect(described_class.digest("x")).to eq(Digest::SHA256.hexdigest("x"))
    end
  end

  describe ".empty" do
    it "has no records" do
      expect(described_class.empty(created_at: "t").records).to eq([])
    end
  end

  describe "#with_record / #without", :aggregate_failures do
    it "adds a record without mutating the original" do
      base = described_class.empty(created_at: "t")
      expect(base.with_record(record).records).to eq([record])
      expect(base.records).to eq([])
    end

    it "removes the given records" do
      one = described_class.empty(created_at: "t").with_record(record)
      expect(one.without([record]).records).to eq([])
    end
  end

  describe "#find" do
    it "matches an entry on name, version, and platform ignoring created_at" do
      manifest = described_class.empty(created_at: "t").with_record(record)
      query = Gemvault::GemEntry.new(name: "foo", version: "1.0.0")
      expect(manifest.find(query)).to eq(record)
    end

    it "returns nil when absent" do
      query = Gemvault::GemEntry.new(name: "x", version: "1")
      expect(described_class.empty(created_at: "t").find(query)).to be_nil
    end
  end

  describe "#gem_entries" do
    it "returns the stored gems' entries sorted by name then version" do
      manifest = described_class.empty(created_at: "t").with_record(record)
      expect(manifest.gem_entries).to eq([entry])
    end
  end

  describe "#matching" do
    let(:foo_two) do
      Gemvault::Manifest::StoredGem.new(
        gem: Gemvault::GemEntry.new(name: "foo", version: "2.0.0"), sha256: "def", encrypted: false,
      )
    end
    let(:manifest) { described_class.empty(created_at: "t").with_record(record).with_record(foo_two) }

    it "selects every stored gem the reference matches" do
      expect(manifest.matching(Gemvault::GemReference.parse("foo"))).to contain_exactly(record, foo_two)
    end

    it "narrows to one gem when the reference names an exact version" do
      expect(manifest.matching(Gemvault::GemReference.parse("foo", version: "1.0.0"))).to eq([record])
    end

    it "is empty when nothing matches" do
      expect(manifest.matching(Gemvault::GemReference.parse("absent"))).to eq([])
    end
  end

  describe "#size" do
    it "counts the stored gems" do
      expect(described_class.empty(created_at: "t").with_record(record).size).to eq(1)
    end
  end

  describe "round-trip .parse / #to_json" do
    it "preserves identity, checksum, and created_at" do
      manifest = described_class.empty(created_at: "t").with_record(record)
      expect(described_class.parse(manifest.to_json).records).to eq([record])
    end
  end

  describe "#to_h" do
    it "mirrors the on-disk JSON structure with symbol keys", :aggregate_failures do
      manifest = described_class.empty(created_at: "t").with_record(record)
      expect(manifest.to_h).to include(vault_version: 2, format: "tarvault", created_at: "t")
      expect(manifest.to_h[:gems].first)
        .to include(name: "foo", version: "1.0.0", platform: "ruby", sha256: "abc", encrypted: false)
    end
  end

  describe "StoredGem#matches?" do
    it "is true when the bytes hash to the stored digest" do
      stored = Gemvault::Manifest::StoredGem.new(gem: entry, sha256: described_class.digest("data"), encrypted: false)
      expect(stored.matches?("data")).to be(true)
    end

    it "is false when the bytes have changed" do
      expect(record.matches?("tampered")).to be(false)
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
