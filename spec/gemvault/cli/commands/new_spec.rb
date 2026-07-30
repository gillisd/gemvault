require "gemvault/cli/commands/new"
require "gemvault/vault"

RSpec.describe Gemvault::CLI::Commands::New do
  let(:vault) { instance_double(Gemvault::Vault, close: nil) }

  before { allow(Gemvault::Vault).to receive(:new).and_return(vault) }

  describe "#run" do
    it "creates the vault at the resolved path" do
      invoke(described_class, (gem_dir / "v").to_s)
      expect(Gemvault::Vault).to have_received(:new).with(Pathname(gem_dir / "v.gemv"), create: true)
    end

    it "reports the vault it created" do
      expect { invoke(described_class, (gem_dir / "v.gemv").to_s) }.to output(/Created/).to_stdout
    end

    context "when the parent directory is missing" do
      it "creates it" do
        invoke(described_class, (gem_dir / "path/to/v.gemv").to_s)
        expect(gem_dir / "path/to").to be_a_directory
      end

      it "reports the directory it created" do
        expect { invoke(described_class, (gem_dir / "path/to/v.gemv").to_s) }
          .to output(/Created directory/).to_stdout
      end
    end

    context "when the parent directory already exists" do
      it "reports no directory" do
        expect { invoke(described_class, (gem_dir / "v.gemv").to_s) }
          .not_to output(/Created directory/).to_stdout
      end
    end

    context "when the vault already exists" do
      before { (gem_dir / "taken.gemv").write("") }

      it "writes the path to stderr" do
        expect { invoke(described_class, (gem_dir / "taken.gemv").to_s) }.to output(/already exists/).to_stderr
      end

      it "exits 1" do
        expect(invoke(described_class, (gem_dir / "taken.gemv").to_s)).to eq(1)
      end

      it "creates no vault" do
        invoke(described_class, (gem_dir / "taken.gemv").to_s)
        expect(Gemvault::Vault).not_to have_received(:new)
      end
    end

    context "when the parent path is a file" do
      before { (gem_dir / "blocked").write("") }

      it "writes the reason to stderr" do
        expect { invoke(described_class, (gem_dir / "blocked/v.gemv").to_s) }
          .to output(/blocked/).to_stderr
      end

      it "exits 1" do
        expect(invoke(described_class, (gem_dir / "blocked/v.gemv").to_s)).to eq(1)
      end
    end

    context "when the vault file cannot be written" do
      before { allow(Gemvault::Vault).to receive(:new).and_raise(Errno::EACCES, "denied") }

      it "reports the failure without a backtrace" do
        expect { invoke(described_class, (gem_dir / "v.gemv").to_s) }.to output(/denied/i).to_stderr
      end

      it "exits 1" do
        expect(invoke(described_class, (gem_dir / "v.gemv").to_s)).to eq(1)
      end
    end
  end
end
