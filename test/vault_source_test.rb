require "test_helper"
require "bundler"
require "bundler/plugin/api"
require "bundler/plugin/vault_source"

Bundler::Plugin::VaultSource.include(Bundler::Plugin::API::Source)

class VaultSourceTestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("vault_source_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"
    build_fixture_vault
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  private

  def build_fixture_vault
    @gem1_path = build_gem("alpha", "1.0.0", dir: @gem_build_dir,
                                             files: { "lib/alpha.rb" => 'module Alpha; VERSION = "1.0.0"; end' })
    @gem2_path = build_subdir_gem("beta", "2.0.0", "beta_dir",
                                  files: { "lib/beta.rb" => 'module Beta; VERSION = "2.0.0"; end' })
    populate_vault(@vault_path, @gem1_path, @gem2_path)
  end

  def build_subdir_gem(name, version, subdir, **options)
    dir = @gem_build_dir / subdir
    dir.mkpath
    build_gem(name, version, dir: dir, **options)
  end

  def populate_vault(path, *gem_paths)
    vault = Gemvault::Vault.new(path, create: true)
    gem_paths.each { |gem_path| vault.add(gem_path) }
    vault.close
  end

  def vault_source_with_gem(name, version, subdir, **options)
    gem_path = build_subdir_gem(name, version, subdir, **options)
    vault_path = @tmpdir / "#{name}.gemv"
    populate_vault(vault_path, gem_path)
    create_vault_source(vault_path)
  end

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

class VaultSourceMetadataTest < VaultSourceTestCase
  def test_initialize_resolves_path
    source = create_vault_source(@vault_path)
    assert_equal "vault at #{@vault_path}", source.to_s
  end

  def test_initialize_does_not_validate_vault_existence
    create_vault_source(@tmpdir / "nope.gemv")
  end

  def test_fetch_gemspec_files_raises_when_vault_missing
    source = create_vault_source(@tmpdir / "nope.gemv")
    assert_raises(Bundler::PathError) do
      source.fetch_gemspec_files
    end
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

  def test_options_to_lock
    source = create_vault_source(@vault_path)
    assert_equal({}, source.options_to_lock)
  end
end

class VaultSourceGemspecTest < VaultSourceTestCase
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

  def test_platform_gem
    source = vault_source_with_gem("native", "1.0.0", "native_dir", platform: "x86_64-linux")
    files = source.fetch_gemspec_files
    assert_equal 1, files.length
    spec = Gem::Specification.load(files.first)
    assert_equal "x86_64-linux", spec.platform.to_s
  end

  def test_dependencies_preserved
    source = vault_source_with_gem("depgem", "1.0.0", "dep_dir",
                                   dependencies: [["rake", ">= 13.0"]])
    files = source.fetch_gemspec_files
    spec = Gem::Specification.load(files.first)
    dep = spec.dependencies.find { |d| d.name == "rake" }
    refute_nil dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
  end
end

class VaultSourceInstallTest < VaultSourceTestCase
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

  def test_install_skips_when_already_installed
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    out = capture_reinstall_output(source, spec)

    refute_match(/Installing/, out, "Expected skip on second install, but got Installing output")
    gem_dir = File.join(Bundler.bundle_path, "gems", spec.full_name)
    assert_equal gem_dir, spec.full_gem_path
    assert_path_exists spec.loaded_from
  end

  def test_install_force_reinstalls_when_already_installed
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    out = capture_reinstall_output(source, spec, force: true)

    assert_match(/Installing/, out, "Expected force reinstall to print Installing")
  end

  private

  def capture_reinstall_output(source, spec, force: false)
    out, _err = capture_io do
      Bundler.ui = Bundler::UI::Shell.new
      source.install(spec, force: force)
    end
    out
  end
end
