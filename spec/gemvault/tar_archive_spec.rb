require "gemvault/tar_archive"
require "gemvault/manifest"

RSpec.describe Gemvault::TarArchive do
  let(:path) { gem_dir / "a.tar" }
  let(:archive) { described_class.new(path) }
  let(:pairs) { [[Gemvault::Manifest::FILENAME, "{}"], ["foo-1.0.0.gem", "BINARY\x00DATA"]] }

  describe "#write then #read", :aggregate_failures do
    it "round-trips a named entry's exact bytes" do
      archive.write(pairs)
      expect(archive.read("foo-1.0.0.gem")).to eq("BINARY\x00DATA")
      expect(archive.read(Gemvault::Manifest::FILENAME)).to eq("{}")
    end

    it "writes entries in the given order with manifest.json first" do
      archive.write(pairs)
      first = nil
      Gem::Package::TarReader.new(File.open(path, "rb")) { |r| r.each_entry { |e| first ||= e.full_name } }
      expect(first).to eq(Gemvault::Manifest::FILENAME)
    end
  end

  describe "#gem_pairs" do
    it "returns every non-manifest entry as [name, bytes]" do
      archive.write(pairs)
      expect(archive.gem_pairs).to eq([["foo-1.0.0.gem", "BINARY\x00DATA"]])
    end
  end

  describe "#write" do
    it "is atomic: a failure mid-write leaves the original intact" do
      archive.write(pairs)
      allow(Gem::Package::TarWriter).to receive(:new).and_raise("boom")
      expect { archive.write(pairs) }.to raise_error("boom")
      expect(archive.read("foo-1.0.0.gem")).to eq("BINARY\x00DATA")
    end

    it "creates the temp file in the target directory" do
      archive.write(pairs)
      expect(Dir.children(gem_dir).grep(/tarvault/)).to be_empty
    end
  end
end
