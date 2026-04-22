require "gemvault/cli/commands/remove"
require "gemvault/vault"

RSpec.describe Gemvault::CLI::Commands::Remove do
  describe "#run" do
    let(:vault) { instance_double(Gemvault::Vault, remove: 1) }

    before do
      allow(Gemvault::Vault).to receive(:open).with("v.gemv", create: false).and_yield(vault)
    end

    context "when Vault#remove returns a positive count" do
      it "prints 'Removed N gem(s)' to stdout" do
        allow(vault).to receive(:remove).and_return(3)
        expect { invoke(described_class, "v.gemv", "foo") }.to output(/Removed 3 gem\(s\)/).to_stdout
      end
    end

    context "when Vault#remove returns zero", :aggregate_failures do
      it "exits 1 and writes 'No matching gem found' to stderr" do
        allow(vault).to receive(:remove).and_return(0)
        exit_status = nil
        expect { exit_status = invoke(described_class, "v.gemv", "foo") }.to output(/No matching gem/).to_stderr
        expect(exit_status).to eq(1)
      end
    end

    context "when GemReference.parse raises NonExactVersionError", :aggregate_failures do
      it "exits 1 and writes the offending requirement to stderr" do
        exit_status = nil
        expect {
          exit_status = invoke(described_class, "v.gemv", "foo", "--version", "~> 1.0")
        }.to output(/~> 1\.0/).to_stderr
        expect(exit_status).to eq(1)
      end
    end
  end
end
