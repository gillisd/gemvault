require "gemvault/bundler_installation"
require "gemvault/bundler_patch"

RSpec.describe Gemvault::BundlerPatch do
  let(:plugin_rb) { instance_double(Pathname) }
  let(:installation) do
    instance_double(Gemvault::BundlerInstallation, plugin_rb: plugin_rb, to_s: "/path/plugin.rb")
  end
  let(:successful_status) { instance_double(Process::Status, success?: true) }
  let(:runner_calls) { [] }
  let(:successful_runner) do
    lambda { |*args|
      runner_calls << args
      ["", successful_status]
    }
  end

  subject(:patch) { described_class.new(runner: successful_runner) }

  describe "#apply_to" do
    context "when the marker is not yet in the source" do
      before { allow(plugin_rb).to receive(:read).and_return("def gemfile_install\nend") }

      it "returns an Outcome::Applied" do
        expect(patch.apply_to(installation)).to be_a(described_class::Outcome::Applied)
      end

      it "carries the installation in the outcome" do
        expect(patch.apply_to(installation).installation).to eq(installation)
      end

      it "invokes the patch runner with --forward" do
        patch.apply_to(installation)
        expect(runner_calls.first.first(2)).to eq(["patch", "--forward"])
      end
    end

    context "when the marker is already in the source" do
      before { allow(plugin_rb).to receive(:read).and_return(described_class::MARKER) }

      it "returns an Outcome::AlreadyApplied" do
        expect(patch.apply_to(installation)).to be_a(described_class::Outcome::AlreadyApplied)
      end

      it "carries the installation in the outcome" do
        expect(patch.apply_to(installation).installation).to eq(installation)
      end

      it "does not invoke the patch runner" do
        patch.apply_to(installation)
        expect(runner_calls).to be_empty
      end
    end

    context "when the patch runner reports failure" do
      let(:failing_status) { instance_double(Process::Status, success?: false) }
      let(:failing_runner) { ->(*_args) { ["error output", failing_status] } }

      subject(:patch) { described_class.new(runner: failing_runner) }

      before { allow(plugin_rb).to receive(:read).and_return("def gemfile_install\nend") }

      it "raises PatchFailed" do
        expect { patch.apply_to(installation) }.to raise_error(described_class::PatchFailed)
      end
    end
  end

  describe "#revert_from" do
    context "when the marker is in the source" do
      before { allow(plugin_rb).to receive(:read).and_return(described_class::MARKER) }

      it "returns an Outcome::Reverted" do
        expect(patch.revert_from(installation)).to be_a(described_class::Outcome::Reverted)
      end

      it "carries the installation in the outcome" do
        expect(patch.revert_from(installation).installation).to eq(installation)
      end

      it "invokes the patch runner with --reverse" do
        patch.revert_from(installation)
        expect(runner_calls.first.first(2)).to eq(["patch", "--reverse"])
      end
    end

    context "when the marker is not in the source" do
      before { allow(plugin_rb).to receive(:read).and_return("def gemfile_install\nend") }

      it "returns an Outcome::NotApplied" do
        expect(patch.revert_from(installation)).to be_a(described_class::Outcome::NotApplied)
      end

      it "carries the installation in the outcome" do
        expect(patch.revert_from(installation).installation).to eq(installation)
      end

      it "does not invoke the patch runner" do
        patch.revert_from(installation)
        expect(runner_calls).to be_empty
      end
    end
  end
end
