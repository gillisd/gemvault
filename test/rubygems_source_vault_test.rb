require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"
require_relative "support/rubygems_source_vault_case"

class RubygemsSourceVaultTest < RubygemsSourceVaultCase
  def test_fetch_spec_valid
    spec = vault_source.fetch_spec(name_tuple("alpha", "1.0.0"))

    assert_equal "alpha", spec.name
    assert_equal Gem::Version.new("1.0.0"), spec.version
  end

  def test_fetch_spec_invalid_raises
    assert_raises(Gem::Exception) { vault_source.fetch_spec(name_tuple("nonexistent", "1.0.0")) }
  end

  def test_download_extracts_gem
    source = vault_source
    spec = source.fetch_spec(name_tuple("alpha", "1.0.0"))

    download_dir = @tmpdir / "download"
    download_dir.mkpath

    result = source.download(spec, download_dir.to_s)

    assert_path_exists result
    assert result.end_with?("alpha-1.0.0.gem")
    assert_predicate File.size(result), :positive?
  end

  def test_spaceship_sorts_before_remote
    vault = vault_source
    remote = Gem::Source.new("https://rubygems.org")

    assert_equal 1, vault <=> remote
  end

  def test_spaceship_sorts_after_local
    vault = vault_source
    local = Gem::Source::Local.new

    assert_equal(-1, vault <=> local)
  end

  def test_equality_same_path
    a = vault_source
    b = vault_source

    assert_equal a, b
    assert_equal a.hash, b.hash
  end

  def test_equality_different_path
    other_path = @tmpdir / "other.gemv"
    Gemvault::Vault.new(other_path, create: true).close
    a = vault_source
    b = Gem::Source::Vault.new(other_path)

    refute_equal a, b
  end

  def test_to_s
    assert_equal "vault at #{@vault_path.expand_path}", vault_source.to_s
  end

  def test_dependency_resolver_set
    set = vault_source.dependency_resolver_set

    assert_instance_of Gem::Resolver::VaultSet, set
  end

  def test_dependency_resolver_set_with_prerelease
    set = vault_source.dependency_resolver_set(true)

    assert_instance_of Gem::Resolver::VaultSet, set
    assert set.prerelease
  end
end
