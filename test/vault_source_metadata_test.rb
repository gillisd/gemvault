require "test_helper"
require_relative "support/vault_source_test_case"

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
