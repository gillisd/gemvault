require "gemvault/cli/commands/doctor"

RSpec.describe Gemvault::CLI::Commands::Doctor do
  describe "#run" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:command) { described_class.new(stdout:, stderr:) }
    let(:uninstall) { ["bundle", "plugin", "uninstall", "bundler-source-vault"] }
    let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: true) }
    let(:plugin_root) do
      instance_double(Gemvault::BundlerPluginRoot, unreachable?: false, local: Pathname(".bundle/plugin"),
                                                   consulted: Pathname(".bundle/plugin"))
    end
    let(:index) do
      instance_double(Gemvault::BundlerPluginIndex, snapshot: "recorded index", restore: nil)
    end

    def ghost_double(path)
      instance_double(Gemvault::GhostSpecification, to_s: path)
    end

    def invoke_run
      begin
        command.run
      rescue SystemExit => e
        e.status
      end
    end

    before do
      allow(Gemvault::BundlerGemfile).to receive(:new).and_return(gemfile)
      allow(Gemvault::BundlerPluginRoot).to receive(:new).and_return(plugin_root)
      allow(Gemvault::BundlerPluginIndex).to receive(:new).and_return(index)
      allow(Gemvault::GhostSpecification).to receive(:of).and_return([])
      allow(command).to receive(:system).and_return(true)
    end

    it "uninstalls the bundler-source-vault plugin" do
      command.run

      expect(command).to have_received(:system).with({}, *uninstall)
    end

    it "runs bundle install as a child of the doctor" do
      command.run

      expect(command).to have_received(:system).with("bundle", "install")
    end

    it "snapshots the plugin index before uninstalling", :aggregate_failures do
      command.run

      expect(index).to have_received(:snapshot).ordered
      expect(command).to have_received(:system).with({}, *uninstall).ordered
    end

    it "uninstalls the plugin before reinstalling", :aggregate_failures do
      command.run

      expect(command).to have_received(:system).with({}, *uninstall).ordered
      expect(command).to have_received(:system).with("bundle", "install").ordered
    end

    it "looks for ghost specifications of both gems it ships", :aggregate_failures do
      command.run

      expect(Gemvault::GhostSpecification).to have_received(:of).with("gemvault")
      expect(Gemvault::GhostSpecification).to have_received(:of).with("bundler-source-vault")
    end

    context "when the plugin uninstall fails" do
      before { allow(command).to receive(:system).with({}, *uninstall).and_return(false) }

      it "reports the failure as a single line" do
        invoke_run

        expect(stderr.string).to eq("doctor: bundle plugin uninstall bundler-source-vault failed\n")
      end

      it "exits 1" do
        expect(invoke_run).to eq(1)
      end

      it "does not attempt the reinstall" do
        invoke_run

        expect(command).not_to have_received(:system).with("bundle", "install")
      end

      it "leaves the index alone" do
        invoke_run

        expect(index).not_to have_received(:restore)
      end
    end

    context "when bundle install fails with the plugin reinstalled" do
      before do
        allow(command).to receive(:system).with("bundle", "install").and_return(false)
        allow(index).to receive(:registered?).with("bundler-source-vault").and_return(true)
      end

      it "reports the partial repair as a single line" do
        invoke_run

        expect(stderr.string).to eq(
          "doctor: bundle install failed; the bundler-source-vault plugin itself was reinstalled " \
          "-- fix the install error and re-run bundle install\n",
        )
      end

      it "exits 1" do
        expect(invoke_run).to eq(1)
      end

      it "does not restore the index" do
        invoke_run

        expect(index).not_to have_received(:restore)
      end
    end

    context "when bundle install fails before the plugin was reinstalled" do
      before do
        allow(command).to receive(:system).with("bundle", "install").and_return(false)
        allow(index).to receive(:registered?).with("bundler-source-vault").and_return(false)
      end

      it "restores the index it snapshotted" do
        invoke_run

        expect(index).to have_received(:restore).with("recorded index")
      end

      it "reports the restore as a single line" do
        invoke_run

        expect(stderr.string).to eq(
          "doctor: bundle install failed before reinstalling bundler-source-vault; restored the " \
          "previous plugin index -- fix the install error and re-run gemvault doctor\n",
        )
      end

      it "exits 1" do
        expect(invoke_run).to eq(1)
      end
    end

    context "when the plugin root is one bundler would ignore" do
      let(:plugin_root) do
        instance_double(Gemvault::BundlerPluginRoot, unreachable?: true, local: Pathname(".bundle/plugin"),
                                                     consulted: Pathname(".bundle/plugin"))
      end

      it "points bundler at the project as bundler/inline does" do
        command.run

        expect(command).to have_received(:system)
          .with({ "BUNDLE_GEMFILE" => "Gemfile" }, *uninstall)
      end
    end

    context "when there is no Gemfile but the project owns a plugin root" do
      let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: false) }
      let(:plugin_root) do
        instance_double(Gemvault::BundlerPluginRoot, unreachable?: true, local: Pathname(".bundle/plugin"),
                                                     consulted: Pathname(".bundle/plugin"))
      end

      before { allow(command).to receive(:puts) }

      it "does not run bundle install" do
        command.run

        expect(command).not_to have_received(:system).with("bundle", "install")
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

    context "when there is neither a Gemfile nor a project plugin root" do
      let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: false) }

      before { allow(command).to receive(:puts) }

      it "does not run bundle install" do
        command.run

        expect(command).not_to have_received(:system).with("bundle", "install")
      end

      it "still uninstalls the plugin" do
        command.run

        expect(command).to have_received(:system)
      end

      it "does not claim to have cleared the project's index" do
        command.run

        expect(command).not_to have_received(:puts).with(/Cleared/)
      end

      it "points at the project directory to reinstall" do
        command.run

        expect(command).to have_received(:puts).with(/project directory/)
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
        expect(command).to have_received(:system).with({}, *uninstall).ordered
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

      it "does not touch the plugin" do
        invoke_run

        expect(command).not_to have_received(:system)
      end
    end
  end
end
