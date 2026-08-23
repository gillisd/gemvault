require "gemvault/gem_reference"

RSpec.describe Gemvault::GemReference, ".parse" do
  def specific(name, version) = described_class::SpecificVersion.new(name:, version: Gem::Version.new(version))

  def any(name) = described_class::AnyVersion.new(name:)

  def parse(...) = described_class.parse(...)

  context "with a bare name and no explicit version" do
    it "returns an AnyVersion specification for that name" do
      expect(parse("foo")).to eq(any("foo"))
    end
  end

  context "with a bare name and an explicit exact version" do
    it "returns a SpecificVersion for that name and version" do
      expect(parse("foo", version: "1.0.0")).to eq(specific("foo", "1.0.0"))
    end
  end

  context "with a combined NAME-VERSION input" do
    it "splits on the last hyphen when the trailing segment is a valid version" do
      expect(parse("foo-1.0.0")).to eq(specific("foo", "1.0.0"))
    end

    it "keeps all hyphens in the name when only the final segment is a version" do
      expect(parse("foo-bar-baz-2.3.4")).to eq(specific("foo-bar-baz", "2.3.4"))
    end

    it "treats the whole string as the name when no trailing version is present" do
      expect(parse("foo")).to eq(any("foo"))
    end

    it "treats the whole string as the name when the trailing segment is not a valid version" do
      expect(parse("foo-bar")).to eq(any("foo-bar"))
    end
  end

  context "with a combined NAME-VERSION input AND an explicit version" do
    it "takes the base name from the input and the version from the explicit argument" do
      expect(parse("foo-9.9.9", version: "1.0.0")).to eq(specific("foo", "1.0.0"))
    end
  end

  context "with a ranged version requirement" do
    it "raises NonExactVersionError whose message names the offending requirement" do
      expect { parse("foo", version: "~> 1.0") }.to raise_error(
        described_class::NonExactVersionError, /~> 1\.0/
      )
    end
  end
end
