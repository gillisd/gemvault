require "gemvault/tarball"

RSpec.describe Gemvault::Tarball do
  include_context "with a two-entry tarball"

  describe "#write then #read", :aggregate_failures do
    it "round-trips a named entry's exact bytes" do
      archive.write(entries)
      expect(archive.read("foo-1.0.0.gem")).to eq(blob)
      expect(archive.read("manifest.json")).to eq("{}")
    end

    it "writes entries in the given order with manifest.json first" do
      archive.write(entries)
      expect(first_tar_entry_name(path)).to eq("manifest.json")
    end
  end

  describe "#read" do
    it "returns nil for an absent entry" do
      archive.write(entries)
      expect(archive.read("missing.gem")).to be_nil
    end
  end

  describe "#entries" do
    it "returns every member as an ArchiveEntry of name and bytes" do
      archive.write(entries)
      expect(archive.entries).to eq(entries)
    end
  end
end
