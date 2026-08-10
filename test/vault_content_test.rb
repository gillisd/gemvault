require "test_helper"
require_relative "support/vault_test_case"

class VaultContentTest < VaultTestCase
  def test_gem_data_returns_matching_bytes
    gem_path = foo_gem
    original = gem_path.binread
    vault = create_vault
    vault.add(gem_path)
    retrieved = vault.gem_data(gem_entry(name: "foo", version: "1.0.0"))

    assert_equal original, retrieved
    vault.close
  end

  def test_gem_data_not_found_raises
    vault = create_vault
    assert_raises(Gemvault::Vault::NotFoundError) do
      vault.gem_data(gem_entry(name: "nope", version: "1.0.0"))
    end
    vault.close
  end

  def test_specs_returns_gem_specifications
    vault = vault_containing(foo_gem)

    assert_foo_specification(vault.specs)
    vault.close
  end

  def test_platform_specific_gem
    vault = vault_containing(build_gem(name: "native", version: "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux"))

    entries = vault.gem_entries

    assert_equal "x86_64-linux", entries.first.platform

    specs = vault.specs

    assert_equal "x86_64-linux", specs.first.platform.to_s
    vault.close
  end

  def test_gem_with_dependencies
    vault = vault_containing(build_gem(name: "depgem", version: "1.0.0", dir: @gem_build_dir,
                                       dependencies: [["rake", ">= 13.0"]]))

    spec = vault.specs.first
    dep = spec.dependencies.find { |d| d.name == "rake" }

    refute_nil dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
    vault.close
  end

  private

  def assert_foo_specification(specs)
    assert_equal 1, specs.length
    assert_instance_of Gem::Specification, specs.first
    assert_equal "foo", specs.first.name
    assert_equal Gem::Version.new("1.0.0"), specs.first.version
  end
end
