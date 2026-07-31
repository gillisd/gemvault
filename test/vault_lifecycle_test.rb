require "test_helper"
require_relative "support/vault_test_case"

class VaultLifecycleTest < VaultTestCase
  def test_create_new_vault
    vault = create_vault

    assert_path_exists @vault_path
    assert_equal 0, vault.size
    vault.close
  end

  def test_open_existing_vault
    create_vault.close
    vault = Gemvault::Vault.new(@vault_path)

    assert_equal 0, vault.size
    vault.close
  end

  def test_reopen_vault_preserves_data
    vault = create_vault
    vault.add(foo_gem)
    vault.close

    vault2 = Gemvault::Vault.new(@vault_path)

    assert_equal 1, vault2.size
    vault2.close
  end

  def test_open_nonexistent_raises
    assert_raises(Gemvault::Vault::NotFoundError) do
      Gemvault::Vault.new(@tmpdir / "nope.gemv")
    end
  end

  def test_open_invalid_file_raises
    invalid = @tmpdir / "bad.gemv"
    invalid.write("this is not sqlite")
    assert_raises(Gemvault::Vault::Error) do
      Gemvault::Vault.new(invalid)
    end
  end

  def test_create_existing_raises
    create_vault.close
    assert_raises(Gemvault::Vault::Error) do
      create_vault
    end
  end

  def test_open_yields_vault_and_closes
    create_vault.close
    yielded_vault = nil
    Gemvault::Vault.open(@vault_path) do |vault|
      assert_instance_of Gemvault::Vault, vault
      yielded_vault = vault
    end

    assert_predicate yielded_vault, :closed?
  end

  def test_open_closes_on_raise
    create_vault.close
    yielded_vault = nil
    assert_raises(RuntimeError) do
      Gemvault::Vault.open(@vault_path) do |vault|
        yielded_vault = vault
        raise "boom"
      end
    end
    assert_predicate yielded_vault, :closed?
  end

  def test_open_without_block_raises
    create_vault.close
    assert_raises(ArgumentError) do
      Gemvault::Vault.open(@vault_path)
    end
  end

  def test_close_is_idempotent
    vault = create_vault
    vault.close
    vault.close
  end
end
