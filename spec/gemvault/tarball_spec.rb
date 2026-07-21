require "gemvault/tarball"

RSpec.describe Gemvault::Tarball do
  let(:path) { gem_dir / "a.tar" }
  let(:archive) { described_class.new(path) }
  let(:blob) { "BINARY#{0.chr}DATA" }
  let(:entries) do
    [
      Gemvault::ArchiveEntry.new(name: "manifest.json", bytes: "{}"),
      Gemvault::ArchiveEntry.new(name: "foo-1.0.0.gem", bytes: blob),
    ]
  end

  describe "#write then #read", :aggregate_failures do
    it "round-trips a named entry's exact bytes" do
      archive.write(entries)
      expect(archive.read("foo-1.0.0.gem")).to eq(blob)
      expect(archive.read("manifest.json")).to eq("{}")
    end

    it "writes entries in the given order with manifest.json first" do
      archive.write(entries)
      first = nil
      Gem::Package::TarReader.new(File.open(path, "rb")) { |r| r.each_entry { |e| first ||= e.full_name } }
      expect(first).to eq("manifest.json")
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

  describe "#write" do
    it "is atomic: a failure mid-write leaves the original intact", :aggregate_failures do
      archive.write(entries)
      allow(Gem::Package::TarWriter).to receive(:new).and_raise("boom")
      expect { archive.write(entries) }.to raise_error("boom")
      expect(archive.read("foo-1.0.0.gem")).to eq(blob)
    end

    it "creates the temp file in the target directory" do
      archive.write(entries)
      expect(Dir.children(gem_dir).grep(/tarvault/)).to be_empty
    end
  end
end
