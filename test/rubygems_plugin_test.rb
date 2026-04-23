require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"

class RubygemsSourceVaultTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_rubygems_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"

    # Build two gems and a prerelease, then populate the vault
    @gem1_path = build_gem("alpha", "1.0.0", dir: @gem_build_dir,
                                             files: { "lib/alpha.rb" => "module Alpha; end" })

    dir2 = @tmpdir / "gem2"
    dir2.mkpath
    @gem2_path = build_gem("alpha", "2.0.0", dir: dir2,
                                             files: { "lib/alpha.rb" => "module Alpha; end" })

    dir3 = @tmpdir / "gem3"
    dir3.mkpath
    @gem3_path = build_gem("beta", "1.0.0", dir: dir3,
                                            files: { "lib/beta.rb" => "module Beta; end" })

    dir4 = @tmpdir / "gem4"
    dir4.mkpath
    @gem_pre_path = build_gem("beta", "2.0.0.pre1", dir: dir4,
                                                    files: { "lib/beta.rb" => "module Beta; end" })

    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(@gem1_path)
    vault.add(@gem2_path)
    vault.add(@gem3_path)
    vault.add(@gem_pre_path)
    vault.close
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
    platform_dir = @tmpdir / "gem_native"
    platform_dir.mkpath
    platform_gem = build_gem("alpha", "2.0.0", dir: platform_dir, platform: "x86_64-linux")

    vault = Gemvault::Vault.new(@vault_path)
    vault.add(platform_gem)
    vault.close

    source = Gem::Source::Vault.new(@vault_path)
    latest = source.load_specs(:latest)
    alpha_tuples = latest.select { |t| t.name == "alpha" }

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
end

class RubygemsResolverVaultSetTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_vaultset_test"))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"

    gem_path = build_gem("mygem", "1.0.0", dir: @gem_build_dir,
                                           files: { "lib/mygem.rb" => "module Mygem; end" })

    dir2 = @tmpdir / "gem2"
    dir2.mkpath
    gem2_path = build_gem("mygem", "2.0.0", dir: dir2,
                                            files: { "lib/mygem.rb" => "module Mygem; end" })

    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    vault.add(gem2_path)
    vault.close
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_find_all_matching
    source = Gem::Source::Vault.new(@vault_path)
    set = Gem::Resolver::VaultSet.new(source)

    dep = Gem::Dependency.new("mygem", ">= 0")
    req = Gem::Resolver::DependencyRequest.new(dep, nil)

    results = set.find_all(req)
    assert_equal 2, results.size
    assert(results.all?(Gem::Resolver::IndexSpecification))
    versions = results.map { |r| r.version.to_s }.sort
    assert_equal ["1.0.0", "2.0.0"], versions
  end

  def test_find_all_version_constraint
    source = Gem::Source::Vault.new(@vault_path)
    set = Gem::Resolver::VaultSet.new(source)

    dep = Gem::Dependency.new("mygem", "~> 1.0")
    req = Gem::Resolver::DependencyRequest.new(dep, nil)

    results = set.find_all(req)
    assert_equal 1, results.size
    assert_equal "1.0.0", results.first.version.to_s
  end

  def test_find_all_no_match
    source = Gem::Source::Vault.new(@vault_path)
    set = Gem::Resolver::VaultSet.new(source)

    dep = Gem::Dependency.new("nonexistent", ">= 0")
    req = Gem::Resolver::DependencyRequest.new(dep, nil)

    results = set.find_all(req)
    assert_empty results
  end
end

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
