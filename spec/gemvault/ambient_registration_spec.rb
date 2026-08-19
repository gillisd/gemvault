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
end
