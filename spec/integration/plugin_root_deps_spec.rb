RSpec.describe "plugins.rb preamble", :integration do
  it "makes Plugin.root gem specs discoverable by RubyGems" do
    output, status = podman_run(<<~'SH')
      set -e
      WORKDIR=$(mktemp -d)
      FAKE_ROOT=$WORKDIR/fake_plugin_root
      FAKE_SPECS=$FAKE_ROOT/specifications
      mkdir -p $FAKE_SPECS

      # Extract preamble (everything before the first require line)
      sed -n '/^require/q;p' /gem/shim/plugins.rb > $WORKDIR/preamble.rb

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

      load "$WORKDIR/preamble.rb"

      begin
        Gem::Specification.find_by_name("phantom_dep")
        puts "PASS"
      rescue Gem::MissingSpecError
        abort "FAIL: phantom_dep not findable after plugins.rb preamble"
      end
      RUBY

      ruby $WORKDIR/test_script.rb
    SH
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("PASS")
  end
end
