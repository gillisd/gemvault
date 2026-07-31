require "gemvault/tarball"

RSpec.describe Gemvault::Tarball, "#write" do
  include_context "with a two-entry tarball"

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
