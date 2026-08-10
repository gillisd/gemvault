require "test_helper"

class VaultTestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_test"))
    @vault_path = @tmpdir / "test.gemv"
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  private

  def create_vault
    Gemvault::Vault.new(@vault_path, create: true)
  end

  def specific_version_ref(name:, version:)
    Gemvault::GemReference::SpecificVersion.new(
      name: name, version: Gem::Version.new(version),
    )
  end

  def build_gem_in_subdir(name:, version:, subdir:, **options)
    dir = @gem_build_dir / subdir
    dir.mkpath
    build_gem(name: name, version: version, dir: dir, **options)
  end
end

class VaultLifecycleTest < VaultTestCase
  def test_create_new_vault
    vault = create_vault
    assert_path_exists @vault_path
    assert_equal 0, vault.size
    vault.close
  end

  def test_create_writes_an_empty_vault_file
    Gemvault::Vault.create(@vault_path)
    assert_path_exists @vault_path
  end

  def test_create_leaves_a_reopenable_vault
    Gemvault::Vault.create(@vault_path)
    vault = Gemvault::Vault.new(@vault_path)
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
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)
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

class VaultMutationTest < VaultTestCase
  def test_add_single_gem
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)
    assert_equal 1, vault.size
    vault.close
  end

  def test_add_multiple_gems
    gem1 = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem(name: "bar", version: "2.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem1)
    vault.add(gem2)
    assert_equal 2, vault.size
    vault.close
  end

  def test_add_duplicate_raises
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
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
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)
    count = vault.remove(specific_version_ref(name: "foo", version: "1.0.0"))
    assert_equal 1, count
    assert_equal 0, vault.size
    vault.close
  end

  def test_remove_by_name_only
    gem1 = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem_in_subdir(name: "foo", version: "2.0.0", subdir: "v2")
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
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)
    assert_equal 1, vault.size
    vault.remove(specific_version_ref(name: "foo", version: "1.0.0"))
    assert_equal 0, vault.size
    vault.close
  end
end

class VaultEntriesTest < VaultTestCase
  def test_gem_entries_empty
    vault = create_vault
    assert_equal [], vault.gem_entries
    vault.close
  end

  def test_gem_entries_returns_gem_entry_objects
    gem1 = build_gem(name: "alpha", version: "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem(name: "beta", version: "2.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem1)
    vault.add(gem2)

    entries = vault.gem_entries
    assert_equal 2, entries.length
    assert_alpha_entry(entries.first)
    assert_equal "beta", entries[1].name
    vault.close
  end

  def test_gem_entry_full_name
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)

    entry = vault.gem_entries.first
    assert_equal "foo-1.0.0", entry.full_name
    assert_equal "foo-1.0.0.gem", entry.filename
    vault.close
  end

  def test_gem_entry_full_name_with_platform
    gem_path = build_gem(name: "native", version: "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux")
    vault = create_vault
    vault.add(gem_path)

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
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)

    vault.with_gem_file(gem_entry(name: "foo", version: "1.0.0")) do |path|
      assert_path_exists path
      assert path.end_with?(".gem")
      spec = Gem::Package.new(path).spec
      assert_equal "foo", spec.name
    end
    vault.close
  end

  def test_with_gem_file_unlinks_on_raise
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)

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

class VaultContentTest < VaultTestCase
  def test_gem_data_returns_matching_bytes
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
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
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    vault = create_vault
    vault.add(gem_path)

    specs = vault.specs
    assert_equal 1, specs.length
    assert_instance_of Gem::Specification, specs.first
    assert_equal "foo", specs.first.name
    assert_equal Gem::Version.new("1.0.0"), specs.first.version
    vault.close
  end

  def test_platform_specific_gem
    gem_path = build_gem(name: "native", version: "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux")
    vault = create_vault
    vault.add(gem_path)

    entries = vault.gem_entries
    assert_equal "x86_64-linux", entries.first.platform

    specs = vault.specs
    assert_equal "x86_64-linux", specs.first.platform.to_s
    vault.close
  end

  def test_gem_with_dependencies
    gem_path = build_gem(name: "depgem", version: "1.0.0", dir: @gem_build_dir,
                         dependencies: [["rake", ">= 13.0"]])
    vault = create_vault
    vault.add(gem_path)

    spec = vault.specs.first
    dep = spec.dependencies.find { |d| d.name == "rake" }
    refute_nil dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
    vault.close
  end
end
