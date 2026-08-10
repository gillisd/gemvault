require "test_helper"
require_relative "support/vault_test_case"

class VaultEntriesTest < VaultTestCase
  def test_gem_entries_empty
    vault = create_vault

    assert_equal [], vault.gem_entries
    vault.close
  end

  def test_gem_entries_returns_gem_entry_objects
    vault = vault_containing(build_gem(name: "alpha", version: "1.0.0", dir: @gem_build_dir),
                             build_gem(name: "beta", version: "2.0.0", dir: @gem_build_dir))

    entries = vault.gem_entries

    assert_equal 2, entries.length
    assert_alpha_entry(entries.first)
    assert_equal "beta", entries[1].name
    vault.close
  end

  def test_gem_entry_full_name
    vault = vault_containing(foo_gem)

    entry = vault.gem_entries.first

    assert_equal "foo-1.0.0", entry.full_name
    assert_equal "foo-1.0.0.gem", entry.filename
    vault.close
  end

  def test_gem_entry_full_name_with_platform
    vault = vault_containing(build_gem(name: "native", version: "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux"))

    entry = vault.gem_entries.first

    assert_equal "native-1.0.0-x86_64-linux", entry.full_name
    assert_equal "native-1.0.0-x86_64-linux.gem", entry.filename
    vault.close
  end

  def test_gem_entry_to_s
    entry = Gemvault::GemEntry.new(name: "foo", version: "1.0.0")

    assert_equal "foo-1.0.0", entry.to_s
  end

  def test_gem_entry_to_s_with_platform
    entry = Gemvault::GemEntry.new(name: "native", version: "1.0.0", platform: "x86_64-linux")

    assert_equal "native-1.0.0 (x86_64-linux)", entry.to_s
  end

  def test_with_gem_file_yields_path
    vault = vault_containing(foo_gem)

    vault.with_gem_file(gem_entry(name: "foo", version: "1.0.0")) do |path|
      assert_path_exists path
      assert path.end_with?(".gem")
      spec = Gem::Package.new(path).spec

      assert_equal "foo", spec.name
    end
    vault.close
  end

  def test_with_gem_file_unlinks_on_raise
    vault = vault_containing(foo_gem)

    saved_path = capture_raised_gem_file_path(vault)

    refute_path_exists saved_path
    vault.close
  end

  private

  def assert_alpha_entry(entry)
    assert_instance_of Gemvault::GemEntry, entry
    assert_equal "alpha", entry.name
    assert_equal "1.0.0", entry.version
    assert_equal "ruby", entry.platform
    refute_nil entry.created_at
  end

  def capture_raised_gem_file_path(vault)
    saved_path = nil
    assert_raises(RuntimeError) do
      vault.with_gem_file(gem_entry(name: "foo", version: "1.0.0")) do |path|
        saved_path = path
        raise "boom"
      end
    end
    saved_path
  end
end
