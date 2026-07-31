require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"
require_relative "support/rubygems_source_vault_case"

class RubygemsSourceVaultLoadSpecsTest < RubygemsSourceVaultCase
  def test_load_specs_released
    released = vault_source.load_specs(:released)
    names = released.map { |t| [t.name, t.version.to_s] }.sort
    assert_includes names, ["alpha", "1.0.0"]
    assert_includes names, ["alpha", "2.0.0"]
    assert_includes names, ["beta", "1.0.0"]
    refute_includes names, ["beta", "2.0.0.pre1"]
  end

  def test_load_specs_prerelease
    pre = vault_source.load_specs(:prerelease)
    names = pre.map { |t| [t.name, t.version.to_s] }
    assert_equal [["beta", "2.0.0.pre1"]], names
  end

  def test_load_specs_latest
    latest = vault_source.load_specs(:latest)
    by_name = latest.map { |t| [t.name, t.version.to_s] }.sort
    assert_includes by_name, ["alpha", "2.0.0"]
    refute_includes by_name, ["alpha", "1.0.0"]
  end

  def test_load_specs_latest_preserves_platform_variants
    add_native_alpha_to_vault

    alpha_tuples = vault_source.load_specs(:latest).select { |t| t.name == "alpha" }

    platforms = alpha_tuples.map { |t| t.platform.to_s }.sort
    assert_includes platforms, "ruby"
    assert_includes platforms, "x86_64-linux"
    assert_equal 2, alpha_tuples.length
  end

  def test_load_specs_complete
    all = vault_source.load_specs(:complete)
    assert_equal 4, all.size
  end
end
