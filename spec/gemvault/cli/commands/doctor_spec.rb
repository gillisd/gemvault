require "gemvault/cli/commands/doctor"

RSpec.describe Gemvault::CLI::Commands::Doctor do
  describe "#run" do
    let(:command) { described_class.new }
    let(:uninstall) { ["bundle", "plugin", "uninstall", "bundler-source-vault"] }

    before do
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

    context "when the plugin uninstall fails" do
      before { allow(command).to receive(:system).and_raise("uninstall failed") }

      it "does not exec bundle install", :aggregate_failures do
        expect { command.run }.to raise_error(RuntimeError)
        expect(command).not_to have_received(:exec)
      end
    end
  end
end
