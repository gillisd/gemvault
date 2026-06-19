require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"

# Tests for Gem::Source::Vault spec loading, fetching, and comparison.
class RubygemsSourceVaultTest < Minitest::Test
  include GemvaultTestHelper

  ALPHA_FILES = { "lib/alpha.rb" => "module Alpha; end" }.freeze
  BETA_FILES = { "lib/beta.rb" => "module Beta; end" }.freeze

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_rubygems_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"
    build_fixture_vault
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- Gem::Source::Vault ---

  def test_load_specs_released
    source = Gem::Source::Vault.new(@vault_path)
    released = source.load_specs(:released)
    names = released.map { |t| [t.name, t.version.to_s] }.sort
    assert_includes names, ["alpha", "1.0.0"]
    assert_includes names, ["alpha", "2.0.0"]
    assert_includes names, ["beta", "1.0.0"]
    refute_includes names, ["beta", "2.0.0.pre1"]
  end

  def test_load_specs_prerelease
    source = Gem::Source::Vault.new(@vault_path)
    pre = source.load_specs(:prerelease)
    names = pre.map { |t| [t.name, t.version.to_s] }
    assert_equal [["beta", "2.0.0.pre1"]], names
  end

  def test_load_specs_latest
    source = Gem::Source::Vault.new(@vault_path)
    latest = source.load_specs(:latest)
    by_name = latest.map { |t| [t.name, t.version.to_s] }.sort
    # latest alpha should be 2.0.0
    assert_includes by_name, ["alpha", "2.0.0"]
    refute_includes by_name, ["alpha", "1.0.0"]
  end

  def test_load_specs_latest_preserves_platform_variants
    add_native_alpha_to_vault

    source = Gem::Source::Vault.new(@vault_path)
    alpha_tuples = source.load_specs(:latest).select { |t| t.name == "alpha" }

    platforms = alpha_tuples.map { |t| t.platform.to_s }.sort
    assert_includes platforms, "ruby"
    assert_includes platforms, "x86_64-linux"
    assert_equal 2, alpha_tuples.length
  end

  def test_load_specs_complete
    source = Gem::Source::Vault.new(@vault_path)
    all = source.load_specs(:complete)
    assert_equal 4, all.size
  end

  def test_fetch_spec_valid
    source = Gem::Source::Vault.new(@vault_path)
    tuple = Gem::NameTuple.new("alpha", Gem::Version.new("1.0.0"), "ruby")
    spec = source.fetch_spec(tuple)
    assert_equal "alpha", spec.name
    assert_equal Gem::Version.new("1.0.0"), spec.version
  end

  def test_fetch_spec_invalid_raises
    source = Gem::Source::Vault.new(@vault_path)
    tuple = Gem::NameTuple.new("nonexistent", Gem::Version.new("1.0.0"), "ruby")
    assert_raises(Gem::Exception) { source.fetch_spec(tuple) }
  end

  def test_download_extracts_gem
    source = Gem::Source::Vault.new(@vault_path)
    spec = source.fetch_spec(Gem::NameTuple.new("alpha", Gem::Version.new("1.0.0"), "ruby"))

    download_dir = @tmpdir / "download"
    download_dir.mkpath

    result = source.download(spec, download_dir.to_s)
    assert_path_exists result
    assert result.end_with?("alpha-1.0.0.gem")
    assert File.size(result).positive?
  end

  def test_spaceship_sorts_before_remote
    vault = Gem::Source::Vault.new(@vault_path)
    remote = Gem::Source.new("https://rubygems.org")
    assert_equal 1, vault <=> remote
  end

  def test_spaceship_sorts_after_local
    vault = Gem::Source::Vault.new(@vault_path)
    local = Gem::Source::Local.new
    assert_equal(-1, vault <=> local)
  end

  def test_equality_same_path
    a = Gem::Source::Vault.new(@vault_path)
    b = Gem::Source::Vault.new(@vault_path)
    assert_equal a, b
    assert_equal a.hash, b.hash
  end

  def test_equality_different_path
    other_path = @tmpdir / "other.gemv"
    Gemvault::Vault.new(other_path, create: true).close
    a = Gem::Source::Vault.new(@vault_path)
    b = Gem::Source::Vault.new(other_path)
    refute_equal a, b
  end

  def test_to_s
    source = Gem::Source::Vault.new(@vault_path)
    assert_equal "vault at #{@vault_path.expand_path}", source.to_s
  end

  def test_dependency_resolver_set
    source = Gem::Source::Vault.new(@vault_path)
    set = source.dependency_resolver_set
    assert_instance_of Gem::Resolver::VaultSet, set
  end

  def test_dependency_resolver_set_with_prerelease
    source = Gem::Source::Vault.new(@vault_path)
    set = source.dependency_resolver_set(true)
    assert_instance_of Gem::Resolver::VaultSet, set
    assert set.prerelease
  end

  private

  def build_fixture_vault
    @gem1_path = build_gem("alpha", "1.0.0", dir: @gem_build_dir, files: ALPHA_FILES)
    @gem2_path = build_subdir_gem("alpha", "2.0.0", "gem2", files: ALPHA_FILES)
    @gem3_path = build_subdir_gem("beta", "1.0.0", "gem3", files: BETA_FILES)
    @gem_pre_path = build_subdir_gem("beta", "2.0.0.pre1", "gem4", files: BETA_FILES)
    populate_vault(@vault_path, @gem1_path, @gem2_path, @gem3_path, @gem_pre_path)
  end

  def build_subdir_gem(name, version, subdir, **options)
    dir = @tmpdir / subdir
    dir.mkpath
    build_gem(name, version, dir: dir, **options)
  end

  def populate_vault(path, *gem_paths)
    vault = Gemvault::Vault.new(path, create: true)
    gem_paths.each { |gem_path| vault.add(gem_path) }
    vault.close
  end

  def add_native_alpha_to_vault
    platform_gem = build_subdir_gem("alpha", "2.0.0", "gem_native", platform: "x86_64-linux")
    vault = Gemvault::Vault.new(@vault_path)
    vault.add(platform_gem)
    vault.close
  end
end

# Tests for file:// and vault:// scheme handling in Gem::Source::Vault.
class RubygemsSourceVaultUriTest < Minitest::Test
  def setup
    @vault_path = Pathname(Dir.mktmpdir("gemvault_uri_test")) / "test.gemv"
  end

  def teardown
    FileUtils.rm_rf(@vault_path.dirname)
  end

  def test_file_uri_strips_scheme
    source = Gem::Source::Vault.new("file://#{@vault_path}")
    assert_equal @vault_path.expand_path.to_s, source.path
  end

  def test_file_uri_equals_plain_path
    a = Gem::Source::Vault.new("file://#{@vault_path}")
    b = Gem::Source::Vault.new(@vault_path.to_s)
    assert_equal a, b
  end

  def test_vault_uri_strips_scheme
    source = Gem::Source::Vault.new("vault://#{@vault_path}")
    assert_equal @vault_path.expand_path.to_s, source.path
  end

  def test_vault_uri_equals_plain_path
    a = Gem::Source::Vault.new("vault://#{@vault_path}")
    b = Gem::Source::Vault.new(@vault_path.to_s)
    assert_equal a, b
  end
end

# Tests for Gem::Resolver::VaultSet dependency resolution.
class RubygemsResolverVaultSetTest < Minitest::Test
  include GemvaultTestHelper

  MYGEM_FILES = { "lib/mygem.rb" => "module Mygem; end" }.freeze

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_vaultset_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"
    build_fixture_vault
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_find_all_matching
    results = find_all("mygem", ">= 0")
    assert_equal 2, results.size
    assert(results.all?(Gem::Resolver::IndexSpecification))
    versions = results.map { |r| r.version.to_s }.sort
    assert_equal ["1.0.0", "2.0.0"], versions
  end

  def test_find_all_version_constraint
    results = find_all("mygem", "~> 1.0")
    assert_equal 1, results.size
    assert_equal "1.0.0", results.first.version.to_s
  end

  def test_find_all_no_match
    results = find_all("nonexistent", ">= 0")
    assert_empty results
  end

  private

  def build_fixture_vault
    gem_path = build_gem("mygem", "1.0.0", dir: @gem_build_dir, files: MYGEM_FILES)
    dir2 = @tmpdir / "gem2"
    dir2.mkpath
    gem2_path = build_gem("mygem", "2.0.0", dir: dir2, files: MYGEM_FILES)

    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    vault.add(gem2_path)
    vault.close
  end

  def find_all(name, requirement)
    source = Gem::Source::Vault.new(@vault_path)
    set = Gem::Resolver::VaultSet.new(source)
    dep = Gem::Dependency.new(name, requirement)
    req = Gem::Resolver::DependencyRequest.new(dep, nil)
    set.find_all(req)
  end
end

# Tests for the RubyGems plugin monkey patches and vault source list handling.
class RubygemsPluginMonkeyPatchTest < Minitest::Test
  def test_local_remote_options_has_vault_uri_patch
    assert_includes Gem::LocalRemoteOptions.ancestors, Gemvault::AcceptVaultURI
  end

  def test_local_remote_options_has_vault_source_option_patch
    assert_includes Gem::LocalRemoteOptions.ancestors, Gemvault::AddVaultSourceOption
  end

  def test_source_list_creates_vault_source_for_gemv
    list = Gem::SourceList.new
    src = list << "/path/to/test.gemv"
    assert_instance_of Gem::Source::Vault, src
    assert_equal 1, list.sources.size
  end

  def test_source_list_creates_normal_source_for_url
    list = Gem::SourceList.new
    src = list << "https://rubygems.org/"
    assert_instance_of Gem::Source, src
  end

  def test_source_list_deduplicates_gemv
    list = Gem::SourceList.new
    list << "/path/to/test.gemv"
    list << "/path/to/test.gemv"
    assert_equal 1, list.sources.size
  end
end
