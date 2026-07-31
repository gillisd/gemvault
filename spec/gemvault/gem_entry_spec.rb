require "gemvault/gem_entry"

RSpec.describe Gemvault::GemEntry do
  def entry(**overrides) = described_class.new(name: "foo", version: "1.0.0", **overrides)

  describe ".from_spec" do
    let(:spec) do
      Gem::Specification.new do |s|
        s.name = "foo"
        s.version = "1.2.0"
      end
    end

    it "builds an entry from the spec name, stringified version, and platform" do
      expect(described_class.from_spec(spec)).to eq(entry(version: "1.2.0", platform: "ruby"))
    end

    it "stringifies a native platform" do
      spec.platform = "x86_64-linux"
      expect(described_class.from_spec(spec).platform).to eq("x86_64-linux")
    end

    it "carries the given created_at" do
      expect(described_class.from_spec(spec, created_at: "t1").created_at).to eq("t1")
    end
  end

  describe "#ruby_platform?" do
    it "is true for the default ruby platform" do
      expect(entry).to be_ruby_platform
    end

    it "is false for a native platform" do
      expect(entry(platform: "x86_64-linux")).not_to be_ruby_platform
    end
  end

  describe "defaults" do
    it "defaults platform to ruby" do
      expect(entry.platform).to eq("ruby")
    end

    it "defaults created_at to nil" do
      expect(entry.created_at).to be_nil
    end
  end

  describe "#same_identity_as?" do
    it "is true when name, version, and platform match, ignoring created_at" do
      expect(entry(created_at: "t1").same_identity_as?(entry(created_at: "t2"))).to be(true)
    end

    it "is false when the version differs" do
      expect(entry.same_identity_as?(entry(version: "2.0.0"))).to be(false)
    end
  end

  describe "equality" do
    it "is equal to another entry with the same fields" do
      twin = entry
      expect(entry).to eq(twin)
    end

    it "differs when the version differs" do
      expect(entry).not_to eq(entry(version: "2.0.0"))
    end
  end
end
