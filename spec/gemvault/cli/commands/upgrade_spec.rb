require "gemvault/cli/commands/upgrade"
require "gemvault/vault_upgrade"

RSpec.describe Gemvault::CLI::Commands::Upgrade do
  let(:plan) { Gemvault::VaultUpgrade::Plan.new(from_version: 1, to_version: 2, gem_count: 3) }
  let(:current_plan) { Gemvault::VaultUpgrade::Plan.new(from_version: 2, to_version: 2, gem_count: 1) }
  let(:upgrade) { instance_double(Gemvault::VaultUpgrade, plan:) }

  before { allow(Gemvault::VaultUpgrade).to receive(:new).and_return(upgrade) }

  def run_upgrade(*args) = invoke(described_class, "v.gemv", *args)

  def print_to_stdout(text) = output(a_string_including(text)).to_stdout

  describe "#run" do
    it "performs the upgrade and reports the result" do
      allow(upgrade).to receive(:call).and_return(plan)
      expect { run_upgrade }.to print_to_stdout("Upgraded v.gemv: format 1 -> 2 (3 gems)")
    end

    context "when the vault is already current" do
      before { allow(upgrade).to receive(:plan).and_return(current_plan) }

      it "reports a no-op" do
        expect { run_upgrade }.to print_to_stdout("already current")
      end
    end

    it "reports the plan and does not migrate under --dry-run", :aggregate_failures do
      allow(upgrade).to receive(:call)
      expect { run_upgrade("--dry-run") }.to print_to_stdout("Would upgrade v.gemv: format 1 -> 2")
      expect(upgrade).not_to have_received(:call)
    end

    it "exits 1 and prints the message on a vault error", :aggregate_failures do
      allow(upgrade).to receive(:plan).and_raise(Gemvault::Vault::UnsupportedVersionError, "needs newer gemvault")
      status = nil
      expect { status = run_upgrade }.to output(a_string_including("needs newer gemvault")).to_stderr
      expect(status).to eq(1)
    end
  end
end
