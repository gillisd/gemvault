require "gemvault/cli/commands/remove"
require "gemvault/vault"

RSpec.describe Gemvault::CLI::Commands::Remove do
  describe "#run" do
    let(:vault) { instance_double(Gemvault::Vault) }

    before do
      allow(Gemvault::Vault).to receive(:open).with("v.gemv", create: false).and_yield(vault)
      allow(vault).to receive(:remove).and_return(1)
    end

    def invoke(*argv)
      described_class.main(argv)
    rescue SystemExit => e
      e.status
    end

    context "with a NAME only" do
      it "calls Vault#remove with the name and no version" do
        invoke("v.gemv", "foo")
        expect(vault).to have_received(:remove).with("foo", nil)
      end

      it "prints the removal count to stdout" do
        allow(vault).to receive(:remove).and_return(3)
        expect { invoke("v.gemv", "foo") }.to output(/Removed 3 gem\(s\)/).to_stdout
      end

      it "exits 1 and writes to stderr when the vault has no matching gem" do
        allow(vault).to receive(:remove).and_return(0)
        expect {
          expect(invoke("v.gemv", "foo")).to eq(1)
        }.to output(/No matching gem/).to_stderr
      end
    end

    context "with a positional VERSION argument" do
      it "calls Vault#remove with the name and that exact version string" do
        invoke("v.gemv", "foo", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end
    end

    context "with a combined NAME-VERSION argument" do
      it "splits on the last hyphen when the trailing segment is a valid version" do
        invoke("v.gemv", "foo-1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end

      it "keeps hyphens in the name when only the final segment is a version" do
        invoke("v.gemv", "foo-bar-baz-2.3.4")
        expect(vault).to have_received(:remove).with("foo-bar-baz", "2.3.4")
      end

      it "treats the whole string as a name when no trailing version is present" do
        invoke("v.gemv", "foo")
        expect(vault).to have_received(:remove).with("foo", nil)
      end

      it "treats the whole string as a name when the trailing segment is not a valid version" do
        invoke("v.gemv", "foo-bar")
        expect(vault).to have_received(:remove).with("foo-bar", nil)
      end
    end

    context "with the --version option" do
      it "calls Vault#remove with the name and that exact version string" do
        invoke("v.gemv", "foo", "--version", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end
    end

    context "with the -v short option" do
      it "calls Vault#remove with the name and that exact version string" do
        invoke("v.gemv", "foo", "-v", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end
    end

    context "with multiple version sources supplied" do
      it "lets --version override a positional VERSION argument" do
        invoke("v.gemv", "foo", "9.9.9", "--version", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end

      it "lets --version override a combined NAME-VERSION argument" do
        invoke("v.gemv", "foo-9.9.9", "--version", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end

      it "lets a positional VERSION argument override a combined NAME-VERSION argument" do
        invoke("v.gemv", "foo-9.9.9", "1.0.0")
        expect(vault).to have_received(:remove).with("foo", "1.0.0")
      end
    end

    context "with a non-exact version requirement" do
      it "exits 1 without calling Vault#remove and names the offending requirement in stderr" do
        expect {
          expect(invoke("v.gemv", "foo", "--version", "~> 1.0")).to eq(1)
        }.to output(/~> 1\.0/).to_stderr
        expect(vault).not_to have_received(:remove)
      end
    end
  end
end
