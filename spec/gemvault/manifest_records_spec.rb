require "gemvault/manifest"
require "gemvault/gem_reference"

RSpec.describe "Gemvault::Manifest records" do
  include_context "with a stored foo record"

  describe ".digest" do
    it "returns the SHA256 hexdigest of the bytes" do
      expect(Gemvault::Manifest.digest("x")).to eq(Digest::SHA256.hexdigest("x"))
    end
  end

  describe ".empty" do
    it "has no records" do
      expect(empty_manifest.records).to eq([])
    end
  end

  describe "#with_record / #without", :aggregate_failures do
    it "adds a record without mutating the original" do
      base = empty_manifest
      expect(base.with_record(record).records).to eq([record])
      expect(base.records).to eq([])
    end

    it "removes the given records" do
      expect(one_record_manifest.without([record]).records).to eq([])
    end
  end

  describe "#find" do
    it "matches an entry on name, version, and platform ignoring created_at" do
      query = Gemvault::GemEntry.new(name: "foo", version: "1.0.0")
      expect(one_record_manifest.find(query)).to eq(record)
    end

    it "returns nil when absent" do
      query = Gemvault::GemEntry.new(name: "x", version: "1")
      expect(empty_manifest.find(query)).to be_nil
    end
  end

  describe "#gem_entries" do
    it "returns the stored gems' entries sorted by name then version" do
      expect(one_record_manifest.gem_entries).to eq([entry])
    end
  end

  describe "#size" do
    it "counts the stored gems" do
      expect(one_record_manifest.size).to eq(1)
    end
  end
end
