require "gemvault/gem_reference"
require "gemvault/gem_entry"

RSpec.describe "Gemvault::GemReference matching" do
  def specific(name, version) = Gemvault::GemReference::SpecificVersion.new(name: name, version: Gem::Version.new(version))

  def any(name) = Gemvault::GemReference::AnyVersion.new(name: name)

  describe "#matches?" do
    let(:foo_one) { Gemvault::GemEntry.new(name: "foo", version: "1.0.0") }
    let(:foo_two) { Gemvault::GemEntry.new(name: "foo", version: "2.0.0") }
    let(:bar_one) { Gemvault::GemEntry.new(name: "bar", version: "1.0.0") }

    context "with an AnyVersion reference" do
      subject(:reference) { any("foo") }

      let(:matching_entry) { foo_two }
      let(:nonmatching_entry) { bar_one }

      it_behaves_like "a gem reference"
    end

    context "with a SpecificVersion reference" do
      subject(:reference) { specific("foo", "1.0.0") }

      let(:matching_entry) { foo_one }
      let(:nonmatching_entry) { foo_two }

      it_behaves_like "a gem reference"
    end
  end

  describe "SpecificVersion#eql? / #hash contract" do
    let(:reference) { specific("foo", "1.0.0") }
    let(:duplicate) { specific("foo", "1.0.0") }
    let(:different_version) { specific("foo", "2.0.0") }

    it "treats refs with different versions as not eql?" do
      expect(reference.eql?(different_version)).to be false
    end

    it "treats refs with matching name and version as eql?" do
      expect(reference.eql?(duplicate)).to be true
    end

    it "keeps hash consistent with eql? across equal refs" do
      expect(reference.hash).to eq(duplicate.hash)
    end

    it "produces distinct hashes for refs that are not eql?" do
      expect(reference.hash).not_to eq(different_version.hash)
    end
  end
end
