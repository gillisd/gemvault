require_relative "spec_helper"

RSpec.describe "plugins.rb preamble" do
  before do
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("plugin_root_spec"))
  end

  after { @workdir.rmtree }

  it "makes Plugin.root gem specs discoverable by RubyGems" do
    fake_root = @workdir / "fake_plugin_root"
    fake_specs = fake_root / "specifications"
    fake_specs.mkpath

    plugins_rb = GEM_SOURCE.join("shim", "plugins.rb").read
    preamble = plugins_rb.lines.take_while { |l| !l.match?(/^require\b/) }.join

    preamble_path = @workdir / "preamble.rb"
    preamble_path.write(preamble)

    script_path = @workdir / "test_plugin_root_deps.rb"
    script_path.write(<<~RUBY)
      require "bundler"

      fake_spec = Gem::Specification.new do |s|
        s.name = "phantom_dep"
        s.version = "1.0.0"
        s.summary = "Simulated plugin dependency"
        s.authors = ["Test"]
        s.files = []
      end
      File.write("#{fake_specs / "phantom_dep-1.0.0.gemspec"}", fake_spec.to_ruby)

      begin
        Gem::Specification.find_by_name("phantom_dep")
        $stderr.puts "SETUP ERROR: phantom_dep already visible"
        exit 2
      rescue Gem::MissingSpecError
        # Expected
      end

      module Bundler::Plugin
        remove_method :root if method_defined?(:root)
        define_method(:root) { Pathname.new("#{fake_root}") }
        module_function :root
      end

      load "#{preamble_path}"

      begin
        Gem::Specification.find_by_name("phantom_dep")
        puts "PASS"
      rescue Gem::MissingSpecError
        $stderr.puts "FAIL: phantom_dep not findable after plugins.rb preamble"
        exit 1
      end
    RUBY

    output, status = Open3.capture2e("ruby", script_path.to_s)
    expect(status).to be_success
    expect(output).to match(/PASS/)
  end
end
