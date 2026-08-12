require "gemvault"
require "gemvault/vault_upgrade"

RSpec.describe Gemvault::VaultUpgrade do
  subject(:upgrade) { described_class.new(vault_path) }

  describe "#plan" do
    it "reports from/to versions and gem count for a Dbvault" do
      legacy_dbvault
      expect(upgrade.plan)
        .to have_attributes(from_version: 1, to_version: Gemvault::Vault::CURRENT_FORMAT, gem_count: 2)
    end

    it "renders the format change and gem count" do
      legacy_dbvault
      expect(upgrade.plan.to_s).to eq("format 1 -> 3 (2 gems)")
    end

    it "is a no-op for an already-current vault" do
      current_tarvault
      expect(upgrade.plan.no_op?).to be(true)
    end
  end
end
