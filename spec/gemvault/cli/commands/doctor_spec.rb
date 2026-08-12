require "gemvault/cli/commands/doctor"

RSpec.describe Gemvault::CLI::Commands::Doctor do
  describe "#run" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:command) { described_class.new(stdout: stdout, stderr: stderr) }
    let(:uninstall) { ["bundle", "plugin", "uninstall", "bundler-source-vault"] }
    let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: true) }
    let(:plugin_root) do
      instance_double(Gemvault::BundlerPluginRoot, unreachable?: false, local: Pathname(".bundle/plugin"))
    end

    def ghost_double(path)
      instance_double(Gemvault::GhostSpecification, to_s: path)
    end

    before do
      allow(Gemvault::BundlerGemfile).to receive(:new).and_return(gemfile)
      allow(Gemvault::BundlerPluginRoot).to receive(:new).and_return(plugin_root)
      allow(Gemvault::GhostSpecification).to receive(:of).and_return([])
      allow(command).to receive(:system).and_return(true)
      allow(command).to receive(:exec)
    end

    it "uninstalls the bundler-source-vault plugin, raising on failure" do
      command.run

      expect(command).to have_received(:system).with({}, *uninstall, exception: true)
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

    context "when the plugin root is one bundler would ignore" do
      let(:plugin_root) do
        instance_double(Gemvault::BundlerPluginRoot, unreachable?: true, local: Pathname(".bundle/plugin"))
      end

      it "points bundler at the project as bundler/inline does" do
        command.run

        expect(command).to have_received(:system)
          .with({ "BUNDLE_GEMFILE" => "Gemfile" }, *uninstall, exception: true)
      end
    end

    context "when there is no Gemfile to reinstall from" do
      let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: false) }

      before { allow(command).to receive(:puts) }

      it "does not exec bundle install" do
        command.run

        expect(command).not_to have_received(:exec)
      end

      it "still uninstalls the plugin" do
        command.run

        expect(command).to have_received(:system)
      end

      it "reports the index it cleared" do
        command.run

        expect(command).to have_received(:puts).with(/plugin index/)
      end

      it "explains that an inline gemfile reinstalls it" do
        command.run

        expect(command).to have_received(:puts).with(/inline gemfile/)
      end
    end

    context "when a ghost specification haunts a gem root" do
      let(:ghost) { ghost_double("/roots/specifications/bundler-source-vault-0.2.4.gemspec") }

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

    context "when ghosts of both gems haunt the machine" do
      let(:gemvault_ghost) { ghost_double("/roots/specifications/gemvault-0.2.4.gemspec") }
      let(:shim_ghost) { ghost_double("/roots/specifications/bundler-source-vault-0.2.4.gemspec") }

      before do
        allow(Gemvault::GhostSpecification).to receive(:of).with("gemvault").and_return([gemvault_ghost])
        allow(Gemvault::GhostSpecification).to receive(:of).with("bundler-source-vault").and_return([shim_ghost])
        allow(gemvault_ghost).to receive(:delete)
        allow(shim_ghost).to receive(:delete)
      end

      it "removes every ghost", :aggregate_failures do
        command.run

        expect(gemvault_ghost).to have_received(:delete)
        expect(shim_ghost).to have_received(:delete)
      end

      it "reports every removal" do
        command.run

        expect(stdout.string).to eq(<<~REPORT)
          Removed ghost specification /roots/specifications/gemvault-0.2.4.gemspec
          Removed ghost specification /roots/specifications/bundler-source-vault-0.2.4.gemspec
        REPORT
      end
    end

    context "when a ghost specification cannot be removed" do
      let(:removed) { ghost_double("/roots/specifications/gemvault-0.2.3.gemspec") }
      let(:stuck) { ghost_double("/roots/specifications/gemvault-0.2.4.gemspec") }

      before do
        allow(Gemvault::GhostSpecification).to receive(:of).with("gemvault").and_return([removed, stuck])
        allow(removed).to receive(:delete)
        allow(stuck).to receive(:delete).and_raise(Errno::EACCES, "/roots/specifications/gemvault-0.2.4.gemspec")
      end

      it "reports the failure as a single line" do
        invoke_run

        expect(stderr.string).to eq(
          "doctor: Permission denied - /roots/specifications/gemvault-0.2.4.gemspec " \
          "(re-run with permissions for that gem home, e.g. sudo gemvault doctor)\n",
        )
      end

      it "exits 1" do
        expect(invoke_run).to eq(1)
      end

      it "reports only the removals it performed" do
        invoke_run

        expect(stdout.string).to eq("Removed ghost specification /roots/specifications/gemvault-0.2.3.gemspec\n")
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
