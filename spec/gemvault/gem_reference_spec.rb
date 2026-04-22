require "gemvault/gem_reference"

RSpec.describe Gemvault::GemReference do
  describe ".parse" do
    context "with a bare name and no explicit version" do
      it "returns an AnyVersion specification for that name" do
        expect(described_class.parse("foo"))
          .to eq(described_class::AnyVersion.new(name: "foo"))
      end
    end

    context "with a bare name and an explicit exact version" do
      it "returns a SpecificVersion for that name and version" do
        expect(described_class.parse("foo", version: "1.0.0"))
          .to eq(described_class::SpecificVersion.new(
            name: "foo", version: Gem::Version.new("1.0.0"),
          ))
      end
    end

    context "with a combined NAME-VERSION input" do
      it "splits on the last hyphen when the trailing segment is a valid version" do
        expect(described_class.parse("foo-1.0.0"))
          .to eq(described_class::SpecificVersion.new(
            name: "foo", version: Gem::Version.new("1.0.0"),
          ))
      end

      it "keeps all hyphens in the name when only the final segment is a version" do
        expect(described_class.parse("foo-bar-baz-2.3.4"))
          .to eq(described_class::SpecificVersion.new(
            name: "foo-bar-baz", version: Gem::Version.new("2.3.4"),
          ))
      end

      it "treats the whole string as the name when no trailing version is present" do
        expect(described_class.parse("foo"))
          .to eq(described_class::AnyVersion.new(name: "foo"))
      end

      it "treats the whole string as the name when the trailing segment is not a valid version" do
        expect(described_class.parse("foo-bar"))
          .to eq(described_class::AnyVersion.new(name: "foo-bar"))
      end
    end

    context "with a combined NAME-VERSION input AND an explicit version" do
      it "takes the base name from the input and the version from the explicit argument" do
        expect(described_class.parse("foo-9.9.9", version: "1.0.0"))
          .to eq(described_class::SpecificVersion.new(
            name: "foo", version: Gem::Version.new("1.0.0"),
          ))
      end
    end

    context "with a ranged version requirement" do
      it "raises NonExactVersionError whose message names the offending requirement" do
        expect { described_class.parse("foo", version: "~> 1.0") }.to raise_error(
          Gemvault::GemReference::NonExactVersionError, /~> 1\.0/
        )
      end
    end
  end
end
