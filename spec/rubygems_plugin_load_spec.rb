require "open3"

RSpec.describe "the RubyGems plugin under Bundler's path-gem loading" do
  def plugin_outcome(expression)
    plugin = File.expand_path("../lib/rubygems_plugin.rb", __dir__)
    env = { "GEM_HOME" => gem_dir.to_s, "GEM_PATH" => gem_dir.to_s,
            "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLER_SETUP" => nil }
    script = "Gem.load_plugin_files([#{plugin.inspect}]); #{expression}"
    Open3.capture2e(env, RbConfig.ruby, "-e", script).first
  end

  it "loads with nothing to activate and lib/ off the load path" do
    expect(plugin_outcome("nil")).to eq("")
  end

  it "installs the vault source patches" do
    expect(plugin_outcome("print(defined?(Gemvault::PLUGIN_LOADED) ? :loaded : :missed)")).to eq("loaded")
  end
end
