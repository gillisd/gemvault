require "gemvault/gem_entry"

RSpec.describe Gemvault::GemEntry do
  describe ".from_spec" do
    let(:spec) do
      Gem::Specification.new do |s|
        s.name = "foo"
        s.version = "1.2.0"
      end
    end

    it "builds an entry from the spec name, stringified version, and platform" do
      expect(described_class.from_spec(spec))
        .to eq(described_class.new(name: "foo", version: "1.2.0", platform: "ruby"))
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
      expect(described_class.new(name: "foo", version: "1.0.0")).to be_ruby_platform
    end

    it "is false for a native platform" do
      expect(described_class.new(name: "foo", version: "1.0.0", platform: "x86_64-linux"))
        .not_to be_ruby_platform
    end
  end

  describe "#full_name" do
    it "joins name and version for a ruby-platform gem" do
      expect(described_class.new(name: "foo", version: "1.0.0").full_name).to eq("foo-1.0.0")
    end

    it "appends the platform for a native gem" do
      entry = described_class.new(name: "foo", version: "1.0.0", platform: "x86_64-linux")
      expect(entry.full_name).to eq("foo-1.0.0-x86_64-linux")
    end
  end

  describe "#filename" do
    it "is the full name with a .gem suffix" do
      expect(described_class.new(name: "foo", version: "1.0.0").filename).to eq("foo-1.0.0.gem")
    end
  end

  describe "#to_s" do
    it "reads as name-version for a ruby-platform gem" do
      expect(described_class.new(name: "foo", version: "1.0.0").to_s).to eq("foo-1.0.0")
    end

    it "parenthesizes the platform for a native gem" do
      entry = described_class.new(name: "foo", version: "1.0.0", platform: "linux")
      expect(entry.to_s).to eq("foo-1.0.0 (linux)")
    end
  end

  describe "defaults" do
    it "defaults platform to ruby" do
      expect(described_class.new(name: "foo", version: "1.0.0").platform).to eq("ruby")
    end

    it "defaults created_at to nil" do
      expect(described_class.new(name: "foo", version: "1.0.0").created_at).to be_nil
    end
  end

  describe "#same_identity_as?" do
    it "is true when name, version, and platform match, ignoring created_at" do
      a = described_class.new(name: "foo", version: "1.0.0", created_at: "t1")
      b = described_class.new(name: "foo", version: "1.0.0", created_at: "t2")
      expect(a.same_identity_as?(b)).to be(true)
    end

    it "is false when the version differs" do
      a = described_class.new(name: "foo", version: "1.0.0")
      b = described_class.new(name: "foo", version: "2.0.0")
      expect(a.same_identity_as?(b)).to be(false)
    end
  end

  describe "equality" do
    it "is equal to another entry with the same fields" do
      entry = described_class.new(name: "foo", version: "1.0.0")
      twin = described_class.new(name: "foo", version: "1.0.0")
      expect(entry).to eq(twin)
    end

    it "differs when the version differs" do
      expect(described_class.new(name: "foo", version: "1.0.0"))
        .not_to eq(described_class.new(name: "foo", version: "2.0.0"))
    end
  end
end
