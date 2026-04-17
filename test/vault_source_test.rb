require "test_helper"
require "bundler"
require "bundler/plugin/api"
require "bundler/plugin/vault_source"

# Include the Source module directly to avoid plugin registry side effects.
Bundler::Plugin::VaultSource.include(Bundler::Plugin::API::Source)

class VaultSourceTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("vault_source_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"

    # Build fixture gems and create a vault
    @gem1_path = build_gem("alpha", "1.0.0", dir: @gem_build_dir,
                                             files: { "lib/alpha.rb" => 'module Alpha; VERSION = "1.0.0"; end' })

    dir2 = @gem_build_dir / "beta_dir"
    dir2.mkpath
    @gem2_path = build_gem("beta", "2.0.0", dir: dir2,
                                            files: { "lib/beta.rb" => 'module Beta; VERSION = "2.0.0"; end' })

    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(@gem1_path)
    vault.add(@gem2_path)
    vault.close
  end

  def teardown
    @tmpdir.rmtree
  end

  def test_initialize_resolves_path
    source = create_vault_source(@vault_path)
    assert_equal "vault at #{@vault_path}", source.to_s
  end

  def test_initialize_missing_vault_raises
    assert_raises(Bundler::PathError) do
      create_vault_source(@tmpdir / "nope.gemv")
    end
  end

  def test_fetch_gemspec_files_returns_all_gems
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files
    assert_equal 2, files.length
    files.each { |f| assert_path_exists f }
  end

  def test_fetch_gemspec_files_returns_valid_gemspecs
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files
    specs = files.map { |f| Gem::Specification.load(f) }
    names = specs.map(&:name).sort
    assert_equal %w[alpha beta], names
  end

  def test_specs_returns_searchable_index
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha beta]
    specs_list = source.specs.to_a
    names = specs_list.map(&:name).sort
    assert_equal %w[alpha beta], names
  end

  def test_install_extracts_to_bundle_path
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    refute_nil spec, "Expected to find alpha spec"

    source.install(spec)

    gem_dir = Pathname(Bundler.bundle_path) / "gems" / "alpha-1.0.0"
    assert_path_exists gem_dir
  end

  def test_install_sets_full_gem_path
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    refute_nil spec.full_gem_path
    assert_path_exists spec.full_gem_path
  end

  def test_install_sets_loaded_from
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    refute_nil spec.loaded_from
    assert_path_exists spec.loaded_from
  end

  def test_to_lock_format
    source = create_vault_source(@vault_path)
    lock = source.to_lock
    assert_includes lock, "remote: #{@vault_path}"
    assert_includes lock, "type: vault"
  end

  def test_to_s
    source = create_vault_source(@vault_path)
    assert_equal "vault at #{@vault_path}", source.to_s
  end

  def test_equality
    source1 = create_vault_source(@vault_path)
    source2 = create_vault_source(@vault_path)
    assert_equal source1, source2
  end

  def test_inequality
    vault2 = @tmpdir / "other.gemv"
    Gemvault::Vault.new(vault2, create: true).close

    source1 = create_vault_source(@vault_path)
    source2 = create_vault_source(vault2)
    refute_equal source1, source2
  end

  def test_platform_gem
    dir3 = @gem_build_dir / "native_dir"
    dir3.mkpath
    native_gem = build_gem("native", "1.0.0", dir: dir3, platform: "x86_64-linux")

    vault2_path = @tmpdir / "native.gemv"
    vault2 = Gemvault::Vault.new(vault2_path, create: true)
    vault2.add(native_gem)
    vault2.close

    source = create_vault_source(vault2_path)
    files = source.fetch_gemspec_files
    assert_equal 1, files.length
    spec = Gem::Specification.load(files.first)
    assert_equal "x86_64-linux", spec.platform.to_s
  end

  def test_dependencies_preserved
    dir3 = @gem_build_dir / "dep_dir"
    dir3.mkpath
    dep_gem = build_gem("depgem", "1.0.0", dir: dir3,
                                           dependencies: [["rake", ">= 13.0"]])

    vault2_path = @tmpdir / "deps.gemv"
    vault2 = Gemvault::Vault.new(vault2_path, create: true)
    vault2.add(dep_gem)
    vault2.close

    source = create_vault_source(vault2_path)
    files = source.fetch_gemspec_files
    spec = Gem::Specification.load(files.first)
    dep = spec.dependencies.find { |d| d.name == "rake" }
    refute_nil dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
  end

  def test_install_skips_when_already_installed
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec) # first install actually extracts

    # Second install should skip extraction and NOT print "Installing"
    out, _err = capture_io do
      Bundler.ui = Bundler::UI::Shell.new
      source.install(spec)
    end

    refute_match(/Installing/, out, "Expected skip on second install, but got Installing output")
    # Verify load paths still set correctly
    gem_dir = File.join(Bundler.bundle_path, "gems", spec.full_name)
    assert_equal gem_dir, spec.full_gem_path
    assert_path_exists spec.loaded_from
  end

  def test_install_force_reinstalls_when_already_installed
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec) # first install

    # Force reinstall should actually install again
    out, _err = capture_io do
      Bundler.ui = Bundler::UI::Shell.new
      source.install(spec, force: true)
    end

    assert_match(/Installing/, out, "Expected force reinstall to print Installing")
  end

  def test_options_to_lock
    source = create_vault_source(@vault_path)
    assert_equal({}, source.options_to_lock)
  end

  private

  def find_spec(source, name)
    source.specs.to_a.find { |s| s.name == name }
  end

  def create_vault_source(path, dependency_names: [])
    opts = { "uri" => path.to_s, "type" => "vault" }
    source = Bundler::Plugin::VaultSource.new(opts)
    source.dependency_names = dependency_names
    source
  end
end
