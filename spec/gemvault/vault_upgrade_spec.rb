require "gemvault"
require "gemvault/dbvault"
require "gemvault/vault_upgrade"
require "sqlite3"

RSpec.describe Gemvault::VaultUpgrade do
  def build_dbvault(*gems)
    Gemvault::Dbvault.open(vault_path, create: true) do |v|
      gems.each { |name, version| v.add(build_gem(name, version)) }
    end
  end

  describe "#plan" do
    it "reports from/to versions and gem count for a Dbvault", :aggregate_failures do
      build_dbvault(["foo", "1.0.0"])
      plan = described_class.new(vault_path).plan
      expect(plan.from_version).to eq(1)
      expect(plan.to_version).to eq(Gemvault::Vault::CURRENT_FORMAT)
      expect(plan.gem_count).to eq(1)
    end

    it "is a no-op for an already-current vault" do
      Gemvault::Vault.open(vault_path, create: true) { |v| v.add(build_gem("foo", "1.0.0")) }
      expect(described_class.new(vault_path).plan.no_op?).to be(true)
    end
  end

  describe "#call" do
    it "converts a Dbvault into a current-format Tarvault at the same path" do
      build_dbvault(["foo", "1.0.0"])
      described_class.new(vault_path).call
      Gemvault::Vault.open(vault_path) { |v| expect(v.format_version).to eq(Gemvault::Vault::CURRENT_FORMAT) }
    end

    it "preserves every gem" do
      build_dbvault(["foo", "1.0.0"], ["bar", "2.0.0"])
      described_class.new(vault_path).call
      names = Gemvault::Vault.open(vault_path) { |v| v.gem_entries.map(&:name) }
      expect(names).to contain_exactly("foo", "bar")
    end

    it "preserves each gem's created_at" do
      build_dbvault(["foo", "1.0.0"])
      SQLite3::Database.new(vault_path.to_s) { |db| db.execute("UPDATE gems SET created_at = '2000-01-01 00:00:00'") }
      described_class.new(vault_path).call
      after = Gemvault::Vault.open(vault_path) { |v| v.gem_entries.first.created_at }
      expect(after).to eq("2000-01-01 00:00:00")
    end

    it "writes a .bak backup by default" do
      build_dbvault(["foo", "1.0.0"])
      described_class.new(vault_path).call
      expect(File.exist?("#{vault_path}.bak")).to be(true)
    end

    it "does not emit the SQLite deprecation warning while migrating" do
      build_dbvault(["foo", "1.0.0"])
      described_class.new(vault_path).call
      expect(Gemvault::Deprecation.output.string).to be_empty
    end

    it "skips the backup when backup: false" do
      build_dbvault(["foo", "1.0.0"])
      described_class.new(vault_path, backup: false).call
      expect(File.exist?("#{vault_path}.bak")).to be(false)
    end

    it "does not back up or rewrite an already-current vault" do
      Gemvault::Vault.open(vault_path, create: true) { |v| v.add(build_gem("foo", "1.0.0")) }
      described_class.new(vault_path).call
      expect(File.exist?("#{vault_path}.bak")).to be(false)
    end
  end
end
