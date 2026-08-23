require "open3"
require "fileutils"

RSpec.describe "the RubyGems plugin under Bundler's path-gem loading" do
  def clean_world_output(script)
    env = { "GEM_HOME" => gem_dir.to_s, "GEM_PATH" => gem_dir.to_s,
            "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLER_SETUP" => nil }
    Open3.capture2e(env, RbConfig.ruby, "-e", script).first
  end

  def plugin_outcome(expression)
    plugin = File.expand_path("../lib/rubygems_plugin.rb", __dir__)
    clean_world_output("Gem.load_plugin_files([#{plugin.inspect}]); #{expression}")
  end

  def tree_copy(name)
    copy = gem_dir / name
    FileUtils.cp_r(File.expand_path("../lib", __dir__), copy.to_s)
    copy
  end

  it "loads with nothing to activate and lib/ off the load path" do
    expect(plugin_outcome("nil")).to eq("")
  end

  it "installs the vault source patches" do
    expect(plugin_outcome("print(defined?(Gemvault::PLUGIN_LOADED) ? :loaded : :missed)")).to eq("loaded")
  end

  context "when another tree's gemvault core is already loaded" do
    let(:pinned) { tree_copy("pinned") }
    let(:superseding) { tree_copy("superseding") }

    let(:deferral_script) { <<~RUBY }
      require #{pinned.join("gemvault/vault").to_s.inspect}
      require #{pinned.join("gemvault/gem_entry").to_s.inspect}
      Gem.load_plugin_files([#{superseding.join("rubygems_plugin.rb").to_s.inspect}])
    RUBY

    it "defers to the loaded copy" do
      expect(clean_world_output(deferral_script)).to eq("")
    end
  end
end
