require "gemvault"
require "gemvault/vault_upgrade"

RSpec.describe Gemvault::VaultUpgrade do
  subject(:upgrade) { described_class.new(vault_path) }

  def backup_written? = File.exist?("#{vault_path}.bak")

  describe "#plan" do
    it "reports from/to versions and gem count for a Dbvault" do
      legacy_dbvault
      expect(upgrade.plan)
        .to have_attributes(from_version: 1, to_version: Gemvault::Vault::CURRENT_FORMAT, gem_count: 2)
    end

    it "is a no-op for an already-current vault" do
      current_tarvault
      expect(upgrade.plan.no_op?).to be(true)
    end
  end
end
