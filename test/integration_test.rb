# frozen_string_literal: true

require "test_helper"

class IntegrationTest < Minitest::Test
  include GemvaultTestHelper

  INTEGRATION_TMP = Pathname(__dir__).parent / "tmp" / "integration"
  PLUGIN_PATH = Pathname(__dir__).parent

  def setup
    @project_dir = INTEGRATION_TMP / "test_#{name}_#{$$}_#{Time.now.to_i}"
    @project_dir.mkpath
    @bundle_path = @project_dir / "vendor" / "bundle"

    @gem_build_dir = @project_dir / "gem_build"
    @gem_build_dir.mkpath

    # Write a placeholder Gemfile so Bundler treats this as a project
    (@project_dir / "Gemfile").write("# placeholder\n")

    # Pre-install the plugin
    install_plugin!
  end

  def teardown
    @project_dir.rmtree
  end

  def test_basic_install
    gem_path = build_gem("hello_vault", "1.0.0", dir: @gem_build_dir,
      files: { "lib/hello_vault.rb" => 'module HelloVault; VERSION = "1.0.0"; end' })

    vault_path = create_vault("basic.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "hello_vault"
      end
    GEMFILE

    output, status = run_bundle("install")
    assert_predicate status, :success?, "bundle install failed:\n#{output}"
    assert_match(/Bundle complete!/, output)

    gem_dirs = @bundle_path.glob("**/gems/hello_vault-1.0.0")
    refute_empty gem_dirs, "Expected hello_vault-1.0.0 gem directory to exist"
  end

  def test_multiple_gems
    gem1 = build_gem("alpha_vault", "1.0.0", dir: @gem_build_dir,
      files: { "lib/alpha_vault.rb" => 'module AlphaVault; end' })
    dir2 = @gem_build_dir / "beta_dir"
    dir2.mkpath
    gem2 = build_gem("beta_vault", "2.0.0", dir: dir2,
      files: { "lib/beta_vault.rb" => 'module BetaVault; end' })
    dir3 = @gem_build_dir / "gamma_dir"
    dir3.mkpath
    gem3 = build_gem("gamma_vault", "3.0.0", dir: dir3,
      files: { "lib/gamma_vault.rb" => 'module GammaVault; end' })

    vault_path = create_vault("multi.gemv", gem1, gem2, gem3)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "alpha_vault"
        gem "beta_vault"
        gem "gamma_vault"
      end
    GEMFILE

    output, status = run_bundle("install")
    assert_predicate status, :success?, "bundle install failed:\n#{output}"

    %w[alpha_vault-1.0.0 beta_vault-2.0.0 gamma_vault-3.0.0].each do |full_name|
      dirs = @bundle_path.glob("**/gems/#{full_name}")
      refute_empty dirs, "Expected #{full_name} to be installed"
    end
  end

  def test_lockfile_correct
    gem_path = build_gem("locktest", "1.0.0", dir: @gem_build_dir,
      files: { "lib/locktest.rb" => 'module Locktest; end' })

    vault_path = create_vault("lock.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "locktest"
      end
    GEMFILE

    run_bundle!("install")

    lockfile = (@project_dir / "Gemfile.lock").read
    assert_includes lockfile, "PLUGIN SOURCE"
    assert_includes lockfile, "type: vault"
    assert_includes lockfile, "locktest (1.0.0)"
  end

  def test_lockfile_round_trip
    gem_path = build_gem("roundtrip", "1.0.0", dir: @gem_build_dir,
      files: { "lib/roundtrip.rb" => 'module Roundtrip; end' })

    vault_path = create_vault("rt.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "roundtrip"
      end
    GEMFILE

    run_bundle!("install")
    lockfile1 = (@project_dir / "Gemfile.lock").read

    run_bundle!("install")
    lockfile2 = (@project_dir / "Gemfile.lock").read

    assert_equal lockfile1, lockfile2, "Lockfile changed after second install"
  end

  def test_gem_loadable
    gem_path = build_gem("loadme", "1.0.0", dir: @gem_build_dir,
      files: { "lib/loadme.rb" => 'module Loadme; VERSION = "1.0.0"; end' })

    vault_path = create_vault("load.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "loadme"
      end
    GEMFILE

    run_bundle!("install")

    output, status = run_bundle("exec", "ruby", "-e", "require 'loadme'; puts Loadme::VERSION")
    assert_predicate status, :success?, "bundle exec failed:\n#{output}"
    assert_match(/1\.0\.0/, output)
  end

  def test_alongside_rubygems_source
    gem_path = build_gem("vaultgem", "1.0.0", dir: @gem_build_dir,
      files: { "lib/vaultgem.rb" => 'module Vaultgem; end' })

    vault_path = create_vault("mixed.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "https://rubygems.org"

      source "#{vault_path}", type: :vault do
        gem "vaultgem"
      end
    GEMFILE

    output, status = run_bundle("install")
    assert_predicate status, :success?, "bundle install with mixed sources failed:\n#{output}"
    assert_match(/Bundle complete!/, output)
  end

  def test_subset_of_vault
    gem1 = build_gem("want1", "1.0.0", dir: @gem_build_dir,
      files: { "lib/want1.rb" => 'module Want1; end' })
    dir2 = @gem_build_dir / "want2_dir"
    dir2.mkpath
    gem2 = build_gem("want2", "1.0.0", dir: dir2,
      files: { "lib/want2.rb" => 'module Want2; end' })
    dir3 = @gem_build_dir / "skip_dir"
    dir3.mkpath
    gem3 = build_gem("skipme", "1.0.0", dir: dir3,
      files: { "lib/skipme.rb" => 'module Skipme; end' })

    vault_path = create_vault("subset.gemv", gem1, gem2, gem3)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "want1"
        gem "want2"
      end
    GEMFILE

    run_bundle!("install")

    refute_empty @bundle_path.glob("**/gems/want1-1.0.0")
    refute_empty @bundle_path.glob("**/gems/want2-1.0.0")
    assert_empty @bundle_path.glob("**/gems/skipme-1.0.0"),
      "skipme should not be installed"
  end

  def test_dependency_resolution
    # gem_a depends on gem_b, both in vault
    dir_b = @gem_build_dir / "b_dir"
    dir_b.mkpath
    gem_b = build_gem("depb", "1.0.0", dir: dir_b,
      files: { "lib/depb.rb" => 'module Depb; end' })
    gem_a = build_gem("depa", "1.0.0", dir: @gem_build_dir,
      files: { "lib/depa.rb" => "require 'depb'; module Depa; end" },
      dependencies: [["depb", "~> 1.0"]])

    vault_path = create_vault("deps.gemv", gem_a, gem_b)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "depa"
        gem "depb"
      end
    GEMFILE

    output, status = run_bundle("install")
    assert_predicate status, :success?, "bundle install with dependencies failed:\n#{output}"

    refute_empty @bundle_path.glob("**/gems/depa-1.0.0")
    refute_empty @bundle_path.glob("**/gems/depb-1.0.0")
  end

  def test_multi_version_resolution
    dir1 = @gem_build_dir / "mv1"
    dir1.mkpath
    gem_v1 = build_gem("multiver", "1.0.0", dir: dir1,
      files: { "lib/multiver.rb" => 'module Multiver; VERSION = "1.0.0"; end' })
    dir2 = @gem_build_dir / "mv2"
    dir2.mkpath
    gem_v2 = build_gem("multiver", "2.0.0", dir: dir2,
      files: { "lib/multiver.rb" => 'module Multiver; VERSION = "2.0.0"; end' })

    vault_path = create_vault("multiversion.gemv", gem_v1, gem_v2)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "multiver", "~> 2.0"
      end
    GEMFILE

    run_bundle!("install")

    # Only 2.0.0 should be installed
    refute_empty @bundle_path.glob("**/gems/multiver-2.0.0"),
      "Expected multiver-2.0.0 to be installed"
    assert_empty @bundle_path.glob("**/gems/multiver-1.0.0"),
      "multiver-1.0.0 should not be installed"

    # Verify the correct version loads
    output, status = run_bundle("exec", "ruby", "-e", "require 'multiver'; puts Multiver::VERSION")
    assert_predicate status, :success?, "bundle exec failed:\n#{output}"
    assert_match(/2\.0\.0/, output)
  end

  def test_bundler_inline
    # Remove the pre-installed plugin index — bundler/inline handles its own
    # plugin installation, and having it pre-registered causes SourceConflict.
    FileUtils.rm_rf(@project_dir / ".bundle" / "plugin")

    gem_path = build_gem("inline_gem", "1.0.0", dir: @gem_build_dir,
      files: { "lib/inline_gem.rb" => 'module InlineGem; VERSION = "1.0.0"; end' })

    vault_path = create_vault("inline.gemv", gem_path)

    script = <<~RUBY
      require "bundler/inline"

      gemfile(true) do
        plugin "bundler-source-vault", path: "#{PLUGIN_PATH}"

        source "#{vault_path}", type: :vault do
          gem "inline_gem"
        end
      end

      require "inline_gem"
      puts InlineGem::VERSION
    RUBY

    script_path = @project_dir / "inline_test.rb"
    script_path.write(script)

    env = {
      "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
    }
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(env, "ruby", script_path.to_s, chdir: @project_dir.to_s)
    end

    assert_predicate status, :success?, "bundler/inline script failed:\n#{output}"
    assert_match(/1\.0\.0/, output)
  end

  def test_plugins_rb_makes_plugin_root_deps_activatable
    # Reproduces the bug where Bundler installs plugin deps (e.g. sqlite3) into
    # Plugin.root but doesn't add their load paths. On systems where sqlite3
    # isn't a system gem, `require "sqlite3"` fails during plugin loading,
    # causing "No plugin sources available for vault."
    #
    # The test places a dummy gem spec ONLY in a fake Plugin.root/specifications/.
    # It then runs the plugins.rb preamble (the workaround code, without the
    # require_relative that triggers the full vault_source/sqlite3 chain).
    # Without the fix, the spec stays invisible to RubyGems.
    # With the fix, it becomes findable — proving plugin deps are activatable.

    fake_root = @project_dir / "fake_plugin_root"
    fake_specs = fake_root / "specifications"
    fake_specs.mkpath

    # Extract preamble: everything before the require_relative line.
    # This is the workaround code that should add Plugin.root specs to RubyGems.
    # In the broken version, there's nothing here (just a comment + blank line).
    # In the fixed version, this contains the Gem::Specification.dirs patch.
    plugins_rb = (PLUGIN_PATH / "shim" / "plugins.rb").read
    preamble = plugins_rb.lines.take_while { |l| !l.match?(/^require\b/) }.join

    # Build the subprocess script in two parts to avoid heredoc interpolation issues
    preamble_path = @project_dir / "preamble.rb"
    preamble_path.write(preamble)

    script_path = @project_dir / "test_plugin_root_deps.rb"
    script_path.write(<<~RUBY)
      require "bundler"

      # Create a dummy gem spec ONLY in Plugin.root/specifications/
      fake_spec = Gem::Specification.new do |s|
        s.name = "phantom_dep"
        s.version = "1.0.0"
        s.summary = "Simulated plugin dependency"
        s.authors = ["Test"]
        s.files = []
      end
      File.write("#{fake_specs / "phantom_dep-1.0.0.gemspec"}", fake_spec.to_ruby)

      # Verify phantom_dep is NOT findable yet
      begin
        Gem::Specification.find_by_name("phantom_dep")
        $stderr.puts "SETUP ERROR: phantom_dep already visible"
        exit 2
      rescue Gem::MissingSpecError
        # Expected — it only exists in the fake Plugin.root
      end

      # Override Bundler::Plugin.root to our fake root (simulates plugin env)
      module Bundler::Plugin
        remove_method :root if method_defined?(:root)
        define_method(:root) { Pathname.new("#{fake_root}") }
        module_function :root
      end

      # Run the plugins.rb preamble — the code before require_relative.
      # In the broken version: no-op (just comments).
      # In the fixed version: adds Plugin.root/specifications to Gem dirs.
      load "#{preamble_path}"

      # NOW: can RubyGems find the dep that's only in Plugin.root?
      begin
        Gem::Specification.find_by_name("phantom_dep")
        puts "PASS"
      rescue Gem::MissingSpecError
        $stderr.puts "FAIL: phantom_dep not findable after plugins.rb preamble"
        $stderr.puts "Gem::Specification.dirs = " + Gem::Specification.dirs.inspect
        exit 1
      end
    RUBY

    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(
        { "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR) },
        "ruby", script_path.to_s
      )
    end

    assert_predicate status, :success?,
      "plugins.rb should make Plugin.root deps findable by RubyGems:\n#{output}"
  end

  def test_version_constraint_unsatisfied
    gem_path = build_gem("constrained", "1.0.0", dir: @gem_build_dir,
      files: { "lib/constrained.rb" => 'module Constrained; end' })

    vault_path = create_vault("constraint.gemv", gem_path)

    write_gemfile(<<~GEMFILE)
      source "#{vault_path}", type: :vault do
        gem "constrained", "~> 2.0"
      end
    GEMFILE

    output, status = run_bundle("install")
    refute_predicate status, :success?, "Expected bundle install to fail with unsatisfied constraint"
    assert_match(/could not find/i, output)
  end

  private

  def create_vault(name, *gem_paths)
    vault_file = @project_dir / name
    vault = Gemvault::Vault.new(vault_file, create: true)
    gem_paths.each { |gp| vault.add(gp) }
    vault.close
    vault_file
  end

  def write_gemfile(content)
    (@project_dir / "Gemfile").write("# frozen_string_literal: true\n\n#{content}")
  end

  def install_plugin!
    # Manually write the plugin index instead of running `bundle plugin install`
    # which would try to resolve sqlite3 from rubygems.org. The plugin is local
    # and sqlite3 is a system gem — the index just needs to point at our source.
    plugin_dir = @project_dir / ".bundle" / "plugin"
    plugin_dir.mkpath

    # Bundler only loads paths listed in the plugin index, so we must include
    # sqlite3's native extension path alongside our own lib path.
    sqlite3_paths = Gem::Specification.find_by_name("sqlite3").full_require_paths

    load_paths = [(PLUGIN_PATH / "lib").to_s] + sqlite3_paths
    load_paths_yaml = load_paths.map { |p| "  - \"#{p}\"" }.join("\n")

    index_content = <<~YAML
      ---
      commands:
      hooks:
      load_paths:
        bundler-source-vault:
      #{load_paths_yaml}
      plugin_paths:
        bundler-source-vault: "#{PLUGIN_PATH}"
      sources:
        vault: "bundler-source-vault"
    YAML
    (plugin_dir / "index").write(index_content)
  end

  def run_bundle(*args, dir: @project_dir)
    env = {
      "BUNDLE_PATH" => @bundle_path.to_s,
      "BUNDLE_PLUGINS" => "false",
      # Expose system gems so the plugin can load sqlite3
      "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
    }
    cmd = ["bundle", *args]
    Bundler.with_unbundled_env do
      Open3.capture2e(env, *cmd, chdir: dir.to_s)
    end
  end

  def run_bundle!(*args, **kwargs)
    output, status = run_bundle(*args, **kwargs)
    assert_predicate status, :success?, "bundle #{args.join(' ')} failed:\n#{output}"
    [output, status]
  end
end
