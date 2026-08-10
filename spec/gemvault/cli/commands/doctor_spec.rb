require "gemvault/cli/commands/doctor"

RSpec.describe Gemvault::CLI::Commands::Doctor do
  describe "#run" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:command) { described_class.new(stdout: stdout, stderr: stderr) }
    let(:uninstall) { ["bundle", "plugin", "uninstall", "bundler-source-vault"] }

    before do
      allow(Gemvault::GhostSpecification).to receive(:of).and_return([])
      allow(command).to receive(:system).and_return(true)
      allow(command).to receive(:exec)
    end

    it "uninstalls the bundler-source-vault plugin, raising on failure" do
      command.run

      expect(command).to have_received(:system).with(*uninstall, exception: true)
    end

    it "execs bundle install" do
      command.run

      expect(command).to have_received(:exec).with("bundle", "install")
    end

    it "uninstalls the plugin before execing bundle install", :aggregate_failures do
      command.run

      expect(command).to have_received(:system).ordered
      expect(command).to have_received(:exec).ordered
    end

    it "looks for ghost specifications of both gems it ships", :aggregate_failures do
      command.run

      expect(Gemvault::GhostSpecification).to have_received(:of).with("gemvault")
      expect(Gemvault::GhostSpecification).to have_received(:of).with("bundler-source-vault")
    end

    context "when the plugin uninstall fails" do
      before { allow(command).to receive(:system).and_raise("uninstall failed") }

      it "does not exec bundle install", :aggregate_failures do
        expect { command.run }.to raise_error(RuntimeError)
        expect(command).not_to have_received(:exec)
      end
    end

    context "when a ghost specification haunts a gem root" do
      let(:ghost) do
        instance_double(Gemvault::GhostSpecification,
                        file: Pathname("/roots/specifications/bundler-source-vault-0.2.4.gemspec"))
      end

      before do
        allow(Gemvault::GhostSpecification).to receive(:of).with("bundler-source-vault").and_return([ghost])
        allow(ghost).to receive(:delete)
      end

      it "removes the ghost" do
        command.run

        expect(ghost).to have_received(:delete)
      end

      it "reports the removal" do
        command.run

        expect(stdout.string)
          .to eq("Removed ghost specification /roots/specifications/bundler-source-vault-0.2.4.gemspec\n")
      end

      it "removes the ghost before uninstalling the plugin", :aggregate_failures do
        command.run

        expect(ghost).to have_received(:delete).ordered
        expect(command).to have_received(:system).ordered
      end
    end

    context "when a ghost specification cannot be removed" do
      let(:ghost) do
        instance_double(Gemvault::GhostSpecification,
                        file: Pathname("/roots/specifications/gemvault-0.2.4.gemspec"))
      end

      before do
        allow(Gemvault::GhostSpecification).to receive(:of).with("gemvault").and_return([ghost])
        allow(ghost).to receive(:delete).and_raise(Errno::EACCES, "/roots/specifications/gemvault-0.2.4.gemspec")
      end

      it "reports the failure without a backtrace" do
        invoke_run

        expect(stderr.string).to include("Permission denied")
      end

      it "exits 1" do
        expect(invoke_run).to eq(1)
      end

      it "does not touch the plugin", :aggregate_failures do
        invoke_run

        expect(command).not_to have_received(:system)
        expect(command).not_to have_received(:exec)
      end

      def invoke_run
        command.run
      rescue SystemExit => e
        e.status
      end
    end
  end
end
