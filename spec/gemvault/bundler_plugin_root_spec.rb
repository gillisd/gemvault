require "gemvault/bundler_plugin_root"

RSpec.describe Gemvault::BundlerPluginRoot do
  subject(:plugin_root) { described_class.new(dir: gem_dir, gemfile: gemfile, env: env) }

  let(:gemfile) { instance_double(Gemvault::BundlerGemfile, exist?: gemfile_present) }
  let(:gemfile_present) { false }
  let(:env) { {} }

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

  describe "#global" do
    it "is the plugin directory under the user's .bundle" do
      expect(plugin_root.global).to eq(Pathname(Dir.home) / ".bundle/plugin")
    end

    context "when BUNDLE_USER_HOME points elsewhere" do
      let(:env) { { "BUNDLE_USER_HOME" => (gem_dir / "bundle-home").to_s } }

      it "follows it" do
        expect(plugin_root.global).to eq(gem_dir / "bundle-home/plugin")
      end
    end

    context "when BUNDLE_USER_PLUGIN names the root directly" do
      let(:env) { { "BUNDLE_USER_PLUGIN" => (gem_dir / "plugin-home").to_s } }

      it "wins over everything" do
        expect(plugin_root.global).to eq(gem_dir / "plugin-home")
      end
    end
  end

  describe "#consulted" do
    context "when a Gemfile was found" do
      let(:gemfile) do
        instance_double(Gemvault::BundlerGemfile, exist?: true, path: gem_dir / "nested/Gemfile")
      end

      it "is the plugin root beside that Gemfile" do
        expect(plugin_root.consulted).to eq(gem_dir / "nested/.bundle/plugin")
      end
    end

    context "when no Gemfile exists but the project owns a plugin root" do
      before { (gem_dir / ".bundle/plugin").mkpath }

      it "is the local root doctor points bundler at" do
        expect(plugin_root.consulted).to eq(plugin_root.local)
      end
    end

    context "when there is neither a Gemfile nor a local plugin root" do
      it "is the global root" do
        expect(plugin_root.consulted).to eq(plugin_root.global)
      end
    end
  end
end
