require "gemvault"
require "gemvault/dbvault"
require "gemvault/tarvault"

RSpec.describe Gemvault::Vault do
  def backend(vault) = vault.instance_variable_get(:@backend)

  describe ".new backend selection", :aggregate_failures do
    it "creates a Tarvault-backed vault by default" do
      expect(backend(described_class.new(vault_path, create: true))).to be_a(Gemvault::Tarvault)
    end

    it "opens an existing tar file as a Tarvault-backed vault" do
      described_class.new(vault_path, create: true)
      expect(backend(described_class.new(vault_path))).to be_a(Gemvault::Tarvault)
    end

    it "opens an existing SQLite file as a Dbvault-backed vault" do
      legacy_dbvault
      expect(backend(described_class.new(vault_path))).to be_a(Gemvault::Dbvault)
    end
  end

  describe "delegation" do
    it "forwards the vault contract to the backend" do
      described_class.open(vault_path, create: true) do |v|
        v.add(build_gem("foo", "1.0.0"))
        expect(v.gem_entries.map(&:name)).to eq(["foo"])
      end
    end
  end

  describe ".open" do
    it "raises ArgumentError without a block" do
      described_class.new(vault_path, create: true)
      expect { described_class.open(vault_path) }.to raise_error(ArgumentError)
    end
  end
end
