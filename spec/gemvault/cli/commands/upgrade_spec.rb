require "gemvault/cli/commands/upgrade"
require "gemvault/vault_upgrade"

RSpec.describe Gemvault::CLI::Commands::Upgrade do
  let(:plan) { Gemvault::VaultUpgrade::Plan.new(from_version: 1, to_version: 2, gem_count: 3) }
  let(:upgrade) { instance_double(Gemvault::VaultUpgrade, plan: plan) }

  before { allow(Gemvault::VaultUpgrade).to receive(:new).and_return(upgrade) }

  describe "#run" do
    it "performs the upgrade and reports the result" do
      allow(upgrade).to receive(:call).and_return(plan)
      expect { invoke(described_class, "v.gemv") }.to output(/Upgraded v\.gemv: format 1 -> 2 \(3 gems\)/).to_stdout
    end

    it "reports a no-op for an already-current vault" do
      allow(upgrade).to receive(:plan).and_return(Gemvault::VaultUpgrade::Plan.new(from_version: 2, to_version: 2, gem_count: 1))
      expect { invoke(described_class, "v.gemv") }.to output(/already current/).to_stdout
    end

    it "reports the plan and does not migrate under --dry-run", :aggregate_failures do
      expect(upgrade).not_to receive(:call)
      expect { invoke(described_class, "v.gemv", "--dry-run") }.to output(/Would upgrade v\.gemv: format 1 -> 2/).to_stdout
    end

    it "exits 1 and prints the message on a vault error", :aggregate_failures do
      allow(upgrade).to receive(:plan).and_raise(Gemvault::Vault::UnsupportedVersionError, "needs newer gemvault")
      status = nil
      expect { status = invoke(described_class, "v.gemv") }.to output(/needs newer gemvault/).to_stderr
      expect(status).to eq(1)
    end
  end
end
