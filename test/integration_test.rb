# frozen_string_literal: true

require "test_helper"

class IntegrationTest < Minitest::Test
  include GemvaultTestHelper

  INTEGRATION_TMP = File.join(__dir__, "..", "tmp", "integration")
  PLUGIN_PATH = File.expand_path("..", __dir__)

  def setup
    @project_dir = File.join(INTEGRATION_TMP, "test_#{name}_#{$$}_#{Time.now.to_i}")
    FileUtils.mkdir_p(@project_dir)
    @bundle_path = File.join(@project_dir, "vendor", "bundle")

    @gem_build_dir = File.join(@project_dir, "gem_build")
    FileUtils.mkdir_p(@gem_build_dir)

    # Write a placeholder Gemfile so Bundler treats this as a project
    File.write(File.join(@project_dir, "Gemfile"), "# placeholder\n")

    # Pre-install the plugin
    install_plugin!
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
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
    assert status.success?, "bundle install failed:\n#{output}"
    assert_match(/Bundle complete!/, output)

    gem_dirs = Dir.glob(File.join(@bundle_path, "**", "gems", "hello_vault-1.0.0"))
    assert gem_dirs.any?, "Expected hello_vault-1.0.0 gem directory to exist"
  end

  def test_multiple_gems
    gem1 = build_gem("alpha_vault", "1.0.0", dir: @gem_build_dir,
      files: { "lib/alpha_vault.rb" => 'module AlphaVault; end' })
    dir2 = File.join(@gem_build_dir, "beta_dir")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("beta_vault", "2.0.0", dir: dir2,
      files: { "lib/beta_vault.rb" => 'module BetaVault; end' })
    dir3 = File.join(@gem_build_dir, "gamma_dir")
    FileUtils.mkdir_p(dir3)
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
    assert status.success?, "bundle install failed:\n#{output}"

    %w[alpha_vault-1.0.0 beta_vault-2.0.0 gamma_vault-3.0.0].each do |full_name|
      dirs = Dir.glob(File.join(@bundle_path, "**", "gems", full_name))
      assert dirs.any?, "Expected #{full_name} to be installed"
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

    lockfile = File.read(File.join(@project_dir, "Gemfile.lock"))
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
    lockfile1 = File.read(File.join(@project_dir, "Gemfile.lock"))

    run_bundle!("install")
    lockfile2 = File.read(File.join(@project_dir, "Gemfile.lock"))

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
    assert status.success?, "bundle exec failed:\n#{output}"
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
    assert status.success?, "bundle install with mixed sources failed:\n#{output}"
    assert_match(/Bundle complete!/, output)
  end

  def test_subset_of_vault
    gem1 = build_gem("want1", "1.0.0", dir: @gem_build_dir,
      files: { "lib/want1.rb" => 'module Want1; end' })
    dir2 = File.join(@gem_build_dir, "want2_dir")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("want2", "1.0.0", dir: dir2,
      files: { "lib/want2.rb" => 'module Want2; end' })
    dir3 = File.join(@gem_build_dir, "skip_dir")
    FileUtils.mkdir_p(dir3)
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

    assert Dir.glob(File.join(@bundle_path, "**", "gems", "want1-1.0.0")).any?
    assert Dir.glob(File.join(@bundle_path, "**", "gems", "want2-1.0.0")).any?
    # skipme should NOT be installed
    refute Dir.glob(File.join(@bundle_path, "**", "gems", "skipme-1.0.0")).any?,
      "skipme should not be installed"
  end

  def test_dependency_resolution
    # gem_a depends on gem_b, both in vault
    dir_b = File.join(@gem_build_dir, "b_dir")
    FileUtils.mkdir_p(dir_b)
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
    assert status.success?, "bundle install with dependencies failed:\n#{output}"

    assert Dir.glob(File.join(@bundle_path, "**", "gems", "depa-1.0.0")).any?
    assert Dir.glob(File.join(@bundle_path, "**", "gems", "depb-1.0.0")).any?
  end

  def test_multi_version_resolution
    dir1 = File.join(@gem_build_dir, "mv1")
    FileUtils.mkdir_p(dir1)
    gem_v1 = build_gem("multiver", "1.0.0", dir: dir1,
      files: { "lib/multiver.rb" => 'module Multiver; VERSION = "1.0.0"; end' })
    dir2 = File.join(@gem_build_dir, "mv2")
    FileUtils.mkdir_p(dir2)
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
    assert Dir.glob(File.join(@bundle_path, "**", "gems", "multiver-2.0.0")).any?,
      "Expected multiver-2.0.0 to be installed"
    refute Dir.glob(File.join(@bundle_path, "**", "gems", "multiver-1.0.0")).any?,
      "multiver-1.0.0 should not be installed"

    # Verify the correct version loads
    output, status = run_bundle("exec", "ruby", "-e", "require 'multiver'; puts Multiver::VERSION")
    assert status.success?, "bundle exec failed:\n#{output}"
    assert_match(/2\.0\.0/, output)
  end

  def test_bundler_inline
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

    script_path = File.join(@project_dir, "inline_test.rb")
    File.write(script_path, script)

    env = {
      "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
    }
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(env, "ruby", script_path, chdir: @project_dir)
    end

    assert status.success?, "bundler/inline script failed:\n#{output}"
    assert_match(/1\.0\.0/, output)
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
    refute status.success?, "Expected bundle install to fail with unsatisfied constraint"
    assert_match(/could not find/i, output)
  end

  private

  def create_vault(name, *gem_paths)
    vault_file = File.join(@project_dir, name)
    vault = Gemvault::Vault.new(vault_file, create: true)
    gem_paths.each { |gp| vault.add(gp) }
    vault.close
    vault_file
  end

  def write_gemfile(content)
    File.write(File.join(@project_dir, "Gemfile"), "# frozen_string_literal: true\n\n#{content}")
  end

  def install_plugin!
    # Manually write the plugin index instead of running `bundle plugin install`
    # which would try to resolve sqlite3 from rubygems.org. The plugin is local
    # and sqlite3 is a system gem — the index just needs to point at our source.
    plugin_dir = File.join(@project_dir, ".bundle", "plugin")
    FileUtils.mkdir_p(plugin_dir)

    # Bundler only loads paths listed in the plugin index, so we must include
    # sqlite3's native extension path alongside our own lib path.
    sqlite3_paths = Gem::Specification.find_by_name("sqlite3").full_require_paths

    load_paths = [File.join(PLUGIN_PATH, "lib")] + sqlite3_paths
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
    File.write(File.join(plugin_dir, "index"), index_content)
  end

  def run_bundle(*args, dir: @project_dir)
    env = {
      "BUNDLE_PATH" => @bundle_path,
      "BUNDLE_PLUGINS" => "false",
      # Expose system gems so the plugin can load sqlite3
      "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
    }
    cmd = ["bundle", *args]
    Bundler.with_unbundled_env do
      Open3.capture2e(env, *cmd, chdir: dir)
    end
  end

  def run_bundle!(*args, **kwargs)
    output, status = run_bundle(*args, **kwargs)
    assert status.success?, "bundle #{args.join(' ')} failed:\n#{output}"
    [output, status]
  end
end
