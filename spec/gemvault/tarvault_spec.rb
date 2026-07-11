require "gemvault/tarvault"

RSpec.describe Gemvault::Tarvault do
  def create(&) = described_class.open(vault_path, create: true, &)

  describe "lifecycle", :aggregate_failures do
    it "creates an empty vault whose manifest.json is the first tar entry" do
      create { |v| expect(v.size).to eq(0) }
      first = nil
      Gem::Package::TarReader.new(File.open(vault_path, "rb")) { |r| r.each_entry { |e| first ||= e.full_name } }
      expect(first).to eq("manifest.json")
    end

    it "raises Vault::Error when creating over an existing file" do
      described_class.new(vault_path, create: true)
      expect { described_class.new(vault_path, create: true) }.to raise_error(Gemvault::Vault::Error)
    end

    it "raises Vault::NotFoundError when opening a missing file" do
      expect { described_class.new(gem_dir / "nope.gemv") }.to raise_error(Gemvault::Vault::NotFoundError)
    end

    it "raises Vault::Error when opening a file that is not a tar" do
      (gem_dir / "bad.gemv").write("this is not a tar")
      expect { described_class.new(gem_dir / "bad.gemv") }.to raise_error(Gemvault::Vault::Error)
    end

    it "reopens and preserves data" do
      create { |v| v.add(build_gem("foo", "1.0.0")) }
      described_class.open(vault_path) { |v| expect(v.size).to eq(1) }
    end
  end

  describe "#add" do
    let(:gem_file) { build_gem("foo", "1.0.0") }

    it "stores a gem and increments size" do
      create { |v| expect { v.add(gem_file) }.to change { v.size }.from(0).to(1) }
    end

    it "preserves a supplied created_at" do
      create do |v|
        v.add(gem_file, created_at: "2000-01-01 00:00:00")
        expect(v.gem_entries.first.created_at).to eq("2000-01-01 00:00:00")
      end
    end

    it "raises Vault::NotFoundError for a missing gem file" do
      create { |v| expect { v.add(gem_dir / "nope.gem") }.to raise_error(Gemvault::Vault::NotFoundError) }
    end

    it "raises Vault::InvalidGemError for a non-gem file" do
      (gem_dir / "bad.gem").write("not a gem")
      create { |v| expect { v.add(gem_dir / "bad.gem") }.to raise_error(Gemvault::Vault::InvalidGemError) }
    end

    it "raises Vault::DuplicateGemError on the same name/version/platform" do
      gem = build_gem("foo", "1.0.0")
      create do |v|
        v.add(gem)
        expect { v.add(gem) }.to raise_error(Gemvault::Vault::DuplicateGemError)
      end
    end

    it "stores a platform-specific gem under its platform filename" do
      create { |v| v.add(build_gem("native", "1.0.0", platform: "x86_64-linux")) }
      described_class.open(vault_path) do |v|
        expect(v.gem_entries.first.filename).to eq("native-1.0.0-x86_64-linux.gem")
      end
    end

    it "re-adds a gem after it was removed" do
      create do |v|
        v.add(gem_file)
        v.remove(Gemvault::GemReference.parse("foo", version: "1.0.0"))
        expect { v.add(gem_file) }.to change { v.size }.from(0).to(1)
      end
    end
  end

  describe "#remove" do
    it "removes one specific version and returns 1" do
      create do |v|
        v.add(build_gem("foo", "1.0.0"))
        expect(v.remove(Gemvault::GemReference.parse("foo", version: "1.0.0"))).to eq(1)
      end
    end

    it "removes all versions by name and returns the count" do
      create do |v|
        v.add(build_gem("foo", "1.0.0"))
        v.add(build_gem("foo", "2.0.0"))
        expect(v.remove(Gemvault::GemReference::AnyVersion.new(name: "foo"))).to eq(2)
      end
    end

    it "returns 0 when nothing matches" do
      create { |v| expect(v.remove(Gemvault::GemReference.parse("nope", version: "1.0.0"))).to eq(0) }
    end
  end

  describe "#gem_data", :aggregate_failures do
    it "returns the exact stored bytes" do
      gem = build_gem("foo", "1.0.0")
      original = File.binread(gem)
      create { |v| v.add(gem) }
      described_class.open(vault_path) { |v| expect(v.gem_data("foo", "1.0.0")).to eq(original) }
    end

    it "raises Vault::NotFoundError for a missing gem" do
      create { |v| expect { v.gem_data("nope", "1.0.0") }.to raise_error(Gemvault::Vault::NotFoundError) }
    end

    it "raises Vault::Error when the stored blob fails its checksum" do
      create { |v| v.add(build_gem("foo", "1.0.0")) }
      corrupt_gem_blob(vault_path)
      described_class.open(vault_path) do |v|
        expect { v.gem_data("foo", "1.0.0") }.to raise_error(Gemvault::Vault::Error, /[Ii]ntegrity/)
      end
    end
  end

  describe "#gem_entries / #specs" do
    it "lists entries as GemEntry objects" do
      create { |v| v.add(build_gem("foo", "1.0.0")) }
      described_class.open(vault_path) { |v| expect(v.gem_entries.first).to be_a(Gemvault::GemEntry) }
    end

    it "loads gemspecs including dependencies and platform" do
      create { |v| v.add(build_gem("dep", "1.0.0", dependencies: [["rake", ">= 13.0"]])) }
      described_class.open(vault_path) do |v|
        expect(v.specs.first.dependencies.map(&:name)).to include("rake")
      end
    end
  end

  describe "GemExtraction" do
    it "yields a real .gem file path from #with_gem_file and unlinks it after" do
      create { |v| v.add(build_gem("foo", "1.0.0")) }
      captured = nil
      described_class.open(vault_path) { |v| v.with_gem_file("foo", "1.0.0") { |p| captured = p } }
      expect(File.exist?(captured)).to be(false)
    end
  end
end
