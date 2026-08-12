require "gemvault"
require "gemvault/vault_upgrade"

RSpec.describe Gemvault::VaultUpgrade, "#call" do
  subject(:upgrade) { described_class.new(vault_path) }

  def backup_written? = File.exist?("#{vault_path}.bak")

  context "with a legacy Dbvault" do
    before do
      legacy_dbvault
      upgrade.call
    end

    it "converts it into a current-format Tarvault at the same path" do
      open_vault { |v| expect(v.format_version).to eq(Gemvault::Vault::CURRENT_FORMAT) }
    end

    it "preserves every gem" do
      names = open_vault { |v| v.gem_entries.map(&:name) }
      expect(names).to contain_exactly("foo", "bar")
    end

    it "preserves each gem's created_at, in the new format's notation" do
      after = open_vault { |v| v.gem_entries.first.created_at }
      expect(after).to eq("2000-01-01T00:00:00Z")
    end

    it "writes a .bak backup by default" do
      expect(backup_written?).to be(true)
    end

    it "does not emit the SQLite deprecation warning while migrating" do
      expect(Gemvault::Deprecation.output.string).to be_empty
    end
  end

  context "with backup: false" do
    subject(:upgrade) { described_class.new(vault_path, backup: false) }

    it "skips the backup" do
      legacy_dbvault
      upgrade.call
      expect(backup_written?).to be(false)
    end
  end

  context "with an already-current vault" do
    it "does not back up or rewrite it" do
      current_tarvault
      upgrade.call
      expect(backup_written?).to be(false)
    end
  end
end
