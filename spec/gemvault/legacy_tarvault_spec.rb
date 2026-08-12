require "gemvault"
require "gemvault/legacy_tarvault"

RSpec.describe Gemvault::LegacyTarvault do
  subject(:vault) { described_class.new(legacy_tarvault) }

  after { vault.close }

  describe "#format_version" do
    it "is the format the vault was written in" do
      expect(vault.format_version).to eq(2)
    end
  end

  describe "#gem_entries" do
    it "lists every gem the archive holds" do
      expect(vault.gem_entries.map(&:name)).to eq(%w[bar foo])
    end

    it "reads each gem's identity from the gem itself" do
      expect(vault.gem_entries.map(&:version)).to eq(%w[2.0.0 1.0.0])
    end

    it "stamps entries in the notation the current format stores" do
      expect(vault.gem_entries.map(&:created_at)).to all(match(Gemvault::Timestamp::CANONICAL))
    end

    it "gives every gem the same stamp, the index it cannot read having held them" do
      expect(vault.gem_entries.map(&:created_at).uniq.size).to eq(1)
    end
  end

  describe "#size" do
    it "counts the gems without reading their specs" do
      expect(vault.size).to eq(2)
    end
  end

  describe "#gem_data" do
    it "returns the bytes of the gem the entry names" do
      entry = vault.gem_entries.first
      expect(Gem::Package.new(StringIO.new(vault.gem_data(entry))).spec.full_name).to eq(entry.full_name)
    end

    it "raises Vault::NotFoundError for a gem the archive lacks" do
      missing = Gemvault::GemEntry.new(name: "nope", version: "1.0.0")
      expect { vault.gem_data(missing) }.to raise_error(Gemvault::Vault::NotFoundError)
    end
  end

  describe "#specs" do
    it "loads each gemspec from its blob" do
      expect(vault.specs.map(&:name)).to contain_exactly("foo", "bar")
    end
  end

  describe "writing" do
    it "refuses add, pointing at upgrade" do
      expect { vault.add("x.gem") }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end

    it "refuses remove, pointing at upgrade" do
      expect { vault.remove("foo") }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end
  end

  describe "opening" do
    it "warns that the format is read-only" do
      output = StringIO.new
      Gemvault::Deprecation.output = output
      described_class.new(legacy_tarvault).close
      expect(output.string).to include("read-only")
    end

    it "raises Vault::NotFoundError for a missing file" do
      expect { described_class.new(gem_dir / "nope.gemv") }.to raise_error(Gemvault::Vault::NotFoundError)
    end
  end
end
