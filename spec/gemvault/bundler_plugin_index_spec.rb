require "gemvault/bundler_plugin_index"

RSpec.describe Gemvault::BundlerPluginIndex do
  subject(:index) { described_class.new(root) }

  let(:root) { gem_dir / ".bundle/plugin" }
  let(:registering) do
    <<~YAML
      ---
      commands: {}
      hooks: {}
      load_paths:
        bundler-source-vault:
        - "/roots/plugin/gems/bundler-source-vault-0.2.5"
      plugin_paths:
        bundler-source-vault: "/roots/plugin/gems/bundler-source-vault-0.2.5"
      sources:
        vault: bundler-source-vault
    YAML
  end
  let(:emptied) do
    <<~YAML
      ---
      commands:
      hooks:
      load_paths:
      plugin_paths:
      sources:
    YAML
  end

  let(:ambient_registering) do
    <<~YAML
      ---
      commands:
      hooks:
      load_paths:
        bundler-source-fake:
        - "/roots/elsewhere/gems/bundler-source-fake-1.0.0/."
        bundler-source-vault:
        - "/roots/ambient/gems/bundler-source-vault-0.2.5/."
      plugin_paths:
        bundler-source-fake: "/roots/elsewhere/gems/bundler-source-fake-1.0.0"
        bundler-source-vault: "/roots/ambient/gems/bundler-source-vault-0.2.5"
      sources:
        fake: "bundler-source-fake"
        vault: "bundler-source-vault"
    YAML
  end

  def write_index(content)
    root.mkpath
    (root / "index").write(content)
  end

  describe "#registered?" do
    it "is true when plugin_paths lists the plugin" do
      write_index(registering)
      expect(index.registered?("bundler-source-vault")).to be(true)
    end

    it "is false when the index was emptied" do
      write_index(emptied)
      expect(index.registered?("bundler-source-vault")).to be(false)
    end

    it "is false when no index exists" do
      expect(index.registered?("bundler-source-vault")).to be(false)
    end

    it "is false for a plugin listed only outside plugin_paths" do
      write_index(registering)
      expect(index.registered?("vault")).to be(false)
    end
  end

  describe "#recorded_path" do
    it "answers the path plugin_paths records for the plugin" do
      write_index(registering)
      expect(index.recorded_path("bundler-source-vault")).to eq("/roots/plugin/gems/bundler-source-vault-0.2.5")
    end

    it "is nil when the plugin is not registered" do
      write_index(registering)
      expect(index.recorded_path("bundler-source-fake")).to be_nil
    end

    it "is nil when the index was emptied" do
      write_index(emptied)
      expect(index.recorded_path("bundler-source-vault")).to be_nil
    end

    it "is nil when no index exists" do
      expect(index.recorded_path("bundler-source-vault")).to be_nil
    end
  end

  describe "#repoint" do
    it "rewrites plugin_paths to the destination" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect(index.recorded_path("bundler-source-vault")).to eq("/roots/plugin/gems/bundler-source-vault-0.2.5")
    end

    it "rewrites a load_paths entry recorded with bundler's trailing /. variant" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect((root / "index").read).to include(%(- "/roots/plugin/gems/bundler-source-vault-0.2.5"))
    end

    it "leaves other plugins' records alone" do
      write_index(ambient_registering)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect(index.recorded_path("bundler-source-fake")).to eq("/roots/elsewhere/gems/bundler-source-fake-1.0.0")
    end

    it "leaves the file alone when the plugin is not registered" do
      write_index(emptied)
      index.repoint("bundler-source-vault", "/roots/plugin/gems/bundler-source-vault-0.2.5")
      expect((root / "index").read).to eq(emptied)
    end
  end

  describe "#snapshot" do
    it "captures the index content" do
      write_index(registering)
      expect(index.snapshot).to eq(registering)
    end

    it "is nil when no index exists" do
      expect(index.snapshot).to be_nil
    end
  end

  describe "#restore" do
    it "writes a captured snapshot back" do
      write_index(registering)
      taken = index.snapshot
      write_index(emptied)

      index.restore(taken)

      expect((root / "index").read).to eq(registering)
    end

    it "removes an index that did not exist at snapshot time" do
      write_index(emptied)

      index.restore(nil)

      expect((root / "index").exist?).to be(false)
    end

    it "tolerates restoring absence onto absence" do
      expect { index.restore(nil) }.not_to raise_error
    end
  end
end
