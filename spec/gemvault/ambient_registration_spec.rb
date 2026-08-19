require "gemvault/ambient_registration"

RSpec.describe Gemvault::AmbientRegistration do
  let(:plugin) { "bundler-source-vault" }
  let(:plugin_root) { gem_dir / ".bundle/plugin" }
  let(:global_root) { gem_dir / "home/.bundle/plugin" }
  let(:roots) { [plugin_root, global_root] }
  let(:gem_home) { gem_dir / "gemhome" }
  let(:ambient_dir) { gem_home / "gems/bundler-source-vault-9.9.9" }

  def install_ambient_shim
    ambient_dir.mkpath
    (ambient_dir / "plugins.rb").write("payload")
    (ambient_dir / "gemvault_load_path.rb").write("payload")
    (gem_home / "specifications").mkpath
    (gem_home / "specifications/bundler-source-vault-9.9.9.gemspec").write("record")
  end

  def register(path)
    plugin_root.mkpath
    (plugin_root / "index").write(<<~YAML)
      ---
      commands:
      hooks:
      load_paths:
        bundler-source-vault:
        - "#{path}/."
      plugin_paths:
        bundler-source-vault: "#{path}"
      sources:
        vault: "bundler-source-vault"
    YAML
  end

  describe ".of" do
    it "finds a registration recorded at an installed gem outside every root" do
      install_ambient_shim
      register(ambient_dir)
      expect(described_class.of(plugin, roots: roots)).not_to be_nil
    end

    it "is nil when the recorded path lies inside a plugin root" do
      register(plugin_root / "gems/bundler-source-vault-9.9.9")
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end

    it "is nil when no installation record sits beside the recorded path" do
      install_ambient_shim
      (gem_home / "specifications/bundler-source-vault-9.9.9.gemspec").delete
      register(ambient_dir)
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end

    it "is nil when nothing is registered" do
      expect(described_class.of(plugin, roots: roots)).to be_nil
    end
  end

  describe "#settle" do
    let(:settled_dir) { plugin_root / "gems/bundler-source-vault-9.9.9" }

    before do
      install_ambient_shim
      register(ambient_dir)
    end

    it "copies the payload into the root's gems directory" do
      described_class.of(plugin, roots: roots).settle
      expect(settled_dir / "plugins.rb").to be_file
    end

    it "copies the installation record into the root's specifications" do
      described_class.of(plugin, roots: roots).settle
      expect(plugin_root / "specifications/bundler-source-vault-9.9.9.gemspec").to be_file
    end

    it "repoints the index at the copy" do
      described_class.of(plugin, roots: roots).settle
      recorded = Gemvault::BundlerPluginIndex.new(plugin_root).recorded_path(plugin)
      expect(recorded).to eq(settled_dir.to_s)
    end

    it "leaves an existing copy in place" do
      settled_dir.mkpath
      (settled_dir / "plugins.rb").write("already settled")
      described_class.of(plugin, roots: roots).settle
      expect((settled_dir / "plugins.rb").read).to eq("already settled")
    end

    it "creates directories closed to group and world writing" do
      described_class.of(plugin, roots: roots).settle
      expect(settled_dir.stat.mode & 0o022).to eq(0)
    end
  end

  describe ".settle" do
    before do
      install_ambient_shim
      register(ambient_dir)
    end

    def with_unwritable_root
      plugin_root.chmod(0o500)
      yield
    ensure
      plugin_root.chmod(0o755)
    end

    it "raises nothing at a machine it cannot write to" do
      expect { with_unwritable_root { described_class.settle(plugin, roots: roots) } }.not_to raise_error
    end

    it "leaves a machine it cannot write to as found" do
      before_settle = (plugin_root / "index").read
      with_unwritable_root { described_class.settle(plugin, roots: roots) }
      expect((plugin_root / "index").read).to eq(before_settle)
    end
  end
end
