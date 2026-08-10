require "gemvault/manifest"
require "gemvault/gem_reference"

RSpec.describe "Gemvault::Manifest matching" do
  include_context "with a stored foo record"

  describe "#matching" do
    let(:foo_two) do
      Gemvault::Manifest::StoredGem.new(
        gem: Gemvault::GemEntry.new(name: "foo", version: "2.0.0"), sha256: "def", encrypted: false,
      )
    end
    let(:manifest) { one_record_manifest.with_record(foo_two) }

    def foo_matching(version: nil) = manifest.matching(Gemvault::GemReference.parse("foo", version: version))

    it "selects every stored gem the reference matches" do
      expect(foo_matching).to contain_exactly(record, foo_two)
    end

    it "narrows to one gem when the reference names an exact version" do
      expect(foo_matching(version: "1.0.0")).to eq([record])
    end

    it "is empty when nothing matches" do
      expect(manifest.matching(Gemvault::GemReference.parse("absent"))).to eq([])
    end
  end
end
