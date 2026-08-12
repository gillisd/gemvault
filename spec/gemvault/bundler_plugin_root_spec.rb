require "gemvault/bundler_plugin_root"

RSpec.describe Gemvault::BundlerPluginRoot do
  subject(:plugin_root) { described_class.new(dir: gem_dir, gemfile: gemfile) }

  let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: gemfile_present) }
  let(:gemfile_present) { false }

  describe "#local" do
    it "is the project's own plugin directory" do
      expect(plugin_root.local).to eq(gem_dir / ".bundle/plugin")
    end
  end

  describe "#unreachable?" do
    context "when a local plugin root exists but no Gemfile does" do
      before { (gem_dir / ".bundle/plugin").mkpath }

      it "is true" do
        expect(plugin_root.unreachable?).to be(true)
      end
    end

    context "when no local plugin root exists" do
      it "is false" do
        expect(plugin_root.unreachable?).to be(false)
      end
    end

    context "when a Gemfile is present" do
      let(:gemfile_present) { true }

      before { (gem_dir / ".bundle/plugin").mkpath }

      it "is false" do
        expect(plugin_root.unreachable?).to be(false)
      end
    end
  end
end
