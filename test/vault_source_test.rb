# frozen_string_literal: true

require "test_helper"
require "bundler"
require "bundler/plugin/api"
require "bundler/plugin/vault_source"

# Include the Source module directly to avoid plugin registry side effects.
Bundler::Plugin::VaultSource.include(Bundler::Plugin::API::Source)

class VaultSourceTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Dir.mktmpdir("vault_source_test")
    @gem_build_dir = File.join(@tmpdir, "gems")
    FileUtils.mkdir_p(@gem_build_dir)
    @vault_path = File.join(@tmpdir, "test.gemv")

    # Build fixture gems and create a vault
    @gem1_path = build_gem("alpha", "1.0.0", dir: @gem_build_dir,
      files: { "lib/alpha.rb" => 'module Alpha; VERSION = "1.0.0"; end' })

    dir2 = File.join(@gem_build_dir, "beta_dir")
    FileUtils.mkdir_p(dir2)
    @gem2_path = build_gem("beta", "2.0.0", dir: dir2,
      files: { "lib/beta.rb" => 'module Beta; VERSION = "2.0.0"; end' })

    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(@gem1_path)
    vault.add(@gem2_path)
    vault.close
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_initialize_resolves_path
    source = create_vault_source(@vault_path)
    assert_equal "vault at #{@vault_path}", source.to_s
  end

  def test_initialize_missing_vault_raises
    assert_raises(Bundler::PathError) do
      create_vault_source(File.join(@tmpdir, "nope.gemv"))
    end
  end

  def test_fetch_gemspec_files_returns_all_gems
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files
    assert_equal 2, files.length
    files.each { |f| assert File.exist?(f), "Expected gemspec file to exist: #{f}" }
  end

  def test_fetch_gemspec_files_returns_valid_gemspecs
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files
    specs = files.map { |f| eval(File.read(f)) } # rubocop:disable Security/Eval
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
    assert spec, "Expected to find alpha spec"

    source.install(spec)

    gem_dir = File.join(Bundler.bundle_path, "gems", "alpha-1.0.0")
    assert File.directory?(gem_dir), "Expected gem dir at #{gem_dir}"
  end

  def test_install_sets_full_gem_path
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    assert spec.full_gem_path
    assert File.directory?(spec.full_gem_path)
  end

  def test_install_sets_loaded_from
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]

    spec = find_spec(source, "alpha")
    source.install(spec)

    assert spec.loaded_from
    assert File.exist?(spec.loaded_from)
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
    vault2 = File.join(@tmpdir, "other.gemv")
    Gemvault::Vault.new(vault2, create: true).close

    source1 = create_vault_source(@vault_path)
    source2 = create_vault_source(vault2)
    refute_equal source1, source2
  end

  def test_platform_gem
    dir3 = File.join(@gem_build_dir, "native_dir")
    FileUtils.mkdir_p(dir3)
    native_gem = build_gem("native", "1.0.0", dir: dir3, platform: "x86_64-linux")

    vault2_path = File.join(@tmpdir, "native.gemv")
    vault2 = Gemvault::Vault.new(vault2_path, create: true)
    vault2.add(native_gem)
    vault2.close

    source = create_vault_source(vault2_path)
    files = source.fetch_gemspec_files
    assert_equal 1, files.length
    spec = eval(File.read(files.first)) # rubocop:disable Security/Eval
    assert_equal "x86_64-linux", spec.platform.to_s
  end

  def test_dependencies_preserved
    dir3 = File.join(@gem_build_dir, "dep_dir")
    FileUtils.mkdir_p(dir3)
    dep_gem = build_gem("depgem", "1.0.0", dir: dir3,
      dependencies: [["rake", ">= 13.0"]])

    vault2_path = File.join(@tmpdir, "deps.gemv")
    vault2 = Gemvault::Vault.new(vault2_path, create: true)
    vault2.add(dep_gem)
    vault2.close

    source = create_vault_source(vault2_path)
    files = source.fetch_gemspec_files
    spec = eval(File.read(files.first)) # rubocop:disable Security/Eval
    dep = spec.dependencies.find { |d| d.name == "rake" }
    assert dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
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
    opts = { "uri" => path, "type" => "vault" }
    source = Bundler::Plugin::VaultSource.new(opts)
    source.dependency_names = dependency_names
    source
  end
end
