require "gemvault/cli/commands/doctor"

RSpec.describe Gemvault::CLI::Commands::Doctor do
  describe "#run" do
    let(:command) { described_class.new }
    let(:uninstall) { ["bundle", "plugin", "uninstall", "bundler-source-vault"] }
    let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: true) }
    let(:plugin_root) do
      instance_double(Gemvault::BundlerPluginRoot, unreachable?: false, local: Pathname(".bundle/plugin"))
    end

    before do
      allow(Gemvault::BundlerGemfile).to receive(:new).and_return(gemfile)
      allow(Gemvault::BundlerPluginRoot).to receive(:new).and_return(plugin_root)
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
  end
end
