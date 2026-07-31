require "test_helper"
require_relative "support/vault_test_case"

class VaultMutationTest < VaultTestCase
  def test_add_single_gem
    vault = vault_containing(foo_gem)
    assert_equal 1, vault.size
    vault.close
  end

  def test_add_multiple_gems
    gem1 = foo_gem
    gem2 = build_gem(name: "bar", version: "2.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem1)
    vault.add(gem2)
    assert_equal 2, vault.size
    vault.close
  end

  def test_add_duplicate_raises
    gem_path = foo_gem
    vault = create_vault
    vault.add(gem_path)
    assert_raises(Gemvault::Vault::DuplicateGemError) do
      vault.add(gem_path)
    end
    vault.close
  end

  def test_add_nonexistent_gem_raises
    vault = create_vault
    assert_raises(Gemvault::Vault::NotFoundError) do
      vault.add(@tmpdir / "nonexistent.gem")
    end
    vault.close
  end

  def test_add_invalid_gem_raises
    bad_gem = @tmpdir / "bad.gem"
    bad_gem.write("not a gem")
    vault = create_vault
    assert_raises(Gemvault::Vault::InvalidGemError) do
      vault.add(bad_gem)
    end
    vault.close
  end

  def test_remove_by_name_and_version
    vault = vault_containing(foo_gem)
    count = vault.remove(specific_version_ref(name: "foo", version: "1.0.0"))
    assert_equal 1, count
    assert_equal 0, vault.size
    vault.close
  end

  def test_remove_by_name_only
    gem1 = foo_gem
    gem2 = build_subdir_gem(name: "foo", version: "2.0.0", subdir: "v2")
    vault = create_vault
    vault.add(gem1)
    vault.add(gem2)
    count = vault.remove(Gemvault::GemReference::AnyVersion.new(name: "foo"))
    assert_equal 2, count
    assert_equal 0, vault.size
    vault.close
  end

  def test_remove_nonexistent_returns_zero
    vault = create_vault
    count = vault.remove(specific_version_ref(name: "nope", version: "1.0.0"))
    assert_equal 0, count
    vault.close
  end

  def test_size_empty
    vault = create_vault
    assert_equal 0, vault.size
    vault.close
  end

  def test_size_after_add_and_remove
    vault = vault_containing(foo_gem)
    assert_equal 1, vault.size
    vault.remove(specific_version_ref(name: "foo", version: "1.0.0"))
    assert_equal 0, vault.size
    vault.close
  end
end
