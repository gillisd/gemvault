module PluginRootProbe
  def run_plugin_root_probe
    podman_run(plugin_root_probe_script)
  end

  def plugin_root_probe_script
    <<~SH
      set -e
      WORKDIR=$(mktemp -d)
      FAKE_ROOT=$WORKDIR/fake_plugin_root
      FAKE_SPECS=$FAKE_ROOT/specifications
      mkdir -p $FAKE_SPECS

      cat > $WORKDIR/test_script.rb <<RUBY
      require "bundler"

      fake_spec = Gem::Specification.new do |s|
        s.name = "phantom_dep"
        s.version = "1.0.0"
        s.summary = "Simulated plugin dependency"
        s.authors = ["Test"]
        s.files = []
      end
      File.write("$FAKE_SPECS/phantom_dep-1.0.0.gemspec", fake_spec.to_ruby)

      begin
        Gem::Specification.find_by_name("phantom_dep")
        abort "SETUP ERROR: phantom_dep already visible"
      rescue Gem::MissingSpecError
        # Expected
      end

      module Bundler::Plugin
        remove_method :root if method_defined?(:root)
        define_method(:root) { Pathname.new("$FAKE_ROOT") }
        module_function :root
      end

      require "/gem/shim/gemvault_load_path"
      BundlerSourceVault::GemvaultLoadPath.register_spec_dirs

      begin
        Gem::Specification.find_by_name("phantom_dep")
        puts "PASS"
      rescue Gem::MissingSpecError
        abort "FAIL: phantom_dep not findable after registering the plugin root"
      end
      RUBY

      ruby $WORKDIR/test_script.rb
    SH
  end
end

RSpec.configure do |config|
  config.include PluginRootProbe, :integration
end
