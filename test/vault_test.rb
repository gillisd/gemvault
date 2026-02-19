# frozen_string_literal: true

require "test_helper"

class VaultTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Dir.mktmpdir("gemvault_test")
    @vault_path = File.join(@tmpdir, "test.gemv")
    @gem_build_dir = File.join(@tmpdir, "gems")
    FileUtils.mkdir_p(@gem_build_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- Create / Open ---

  def test_create_new_vault
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert File.exist?(@vault_path)
    assert_equal 0, vault.size
    vault.close
  end

  def test_open_existing_vault
    Gemvault::Vault.new(@vault_path, create: true).close
    vault = Gemvault::Vault.new(@vault_path)
    assert_equal 0, vault.size
    vault.close
  end

  def test_reopen_vault_preserves_data
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    vault.close

    vault2 = Gemvault::Vault.new(@vault_path)
    assert_equal 1, vault2.size
    vault2.close
  end

  def test_open_nonexistent_raises
    assert_raises(Gemvault::Vault::NotFoundError) do
      Gemvault::Vault.new(File.join(@tmpdir, "nope.gemv"))
    end
  end

  def test_open_invalid_file_raises
    invalid = File.join(@tmpdir, "bad.gemv")
    File.write(invalid, "this is not sqlite")
    assert_raises(Gemvault::Vault::Error) do
      Gemvault::Vault.new(invalid)
    end
  end

  def test_create_existing_raises
    Gemvault::Vault.new(@vault_path, create: true).close
    assert_raises(Gemvault::Vault::Error) do
      Gemvault::Vault.new(@vault_path, create: true)
    end
  end

  # --- Add ---

  def test_add_single_gem
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    assert_equal 1, vault.size
    vault.close
  end

  def test_add_multiple_gems
    gem1 = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem("bar", "2.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem1)
    vault.add(gem2)
    assert_equal 2, vault.size
    vault.close
  end

  def test_add_duplicate_raises
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    assert_raises(Gemvault::Vault::DuplicateGemError) do
      vault.add(gem_path)
    end
    vault.close
  end

  def test_add_nonexistent_gem_raises
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert_raises(Gemvault::Vault::NotFoundError) do
      vault.add(File.join(@tmpdir, "nonexistent.gem"))
    end
    vault.close
  end

  def test_add_invalid_gem_raises
    bad_gem = File.join(@tmpdir, "bad.gem")
    File.write(bad_gem, "not a gem")
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert_raises(Gemvault::Vault::InvalidGemError) do
      vault.add(bad_gem)
    end
    vault.close
  end

  # --- List ---

  def test_list_empty
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert_equal [], vault.list
    vault.close
  end

  def test_list_with_gems
    gem1 = build_gem("alpha", "1.0.0", dir: @gem_build_dir)
    gem2 = build_gem("beta", "2.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem1)
    vault.add(gem2)

    entries = vault.list
    assert_equal 2, entries.length
    assert_equal "alpha", entries[0]["name"]
    assert_equal "1.0.0", entries[0]["version"]
    assert_equal "ruby", entries[0]["platform"]
    assert entries[0]["created_at"]
    assert_equal "beta", entries[1]["name"]
    vault.close
  end

  def test_list_returns_correct_fields
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)

    entry = vault.list.first
    assert_equal %w[name version platform created_at].sort, entry.keys.select { |k| k.is_a?(String) }.sort
    vault.close
  end

  # --- Remove ---

  def test_remove_by_name_and_version
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    count = vault.remove("foo", "1.0.0")
    assert_equal 1, count
    assert_equal 0, vault.size
    vault.close
  end

  def test_remove_by_name_only
    gem1 = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    dir2 = File.join(@gem_build_dir, "v2")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("foo", "2.0.0", dir: dir2)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem1)
    vault.add(gem2)
    count = vault.remove("foo")
    assert_equal 2, count
    assert_equal 0, vault.size
    vault.close
  end

  def test_remove_nonexistent_returns_zero
    vault = Gemvault::Vault.new(@vault_path, create: true)
    count = vault.remove("nope", "1.0.0")
    assert_equal 0, count
    vault.close
  end

  # --- gem_data ---

  def test_gem_data_returns_matching_bytes
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    original = File.binread(gem_path)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    retrieved = vault.gem_data("foo", "1.0.0")
    assert_equal original, retrieved
    vault.close
  end

  def test_gem_data_not_found_raises
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert_raises(Gemvault::Vault::NotFoundError) do
      vault.gem_data("nope", "1.0.0")
    end
    vault.close
  end

  # --- specs ---

  def test_specs_returns_gem_specifications
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)

    specs = vault.specs
    assert_equal 1, specs.length
    assert_instance_of Gem::Specification, specs.first
    assert_equal "foo", specs.first.name
    assert_equal Gem::Version.new("1.0.0"), specs.first.version
    vault.close
  end

  # --- Platform gem ---

  def test_platform_specific_gem
    gem_path = build_gem("native", "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux")
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)

    entries = vault.list
    assert_equal "x86_64-linux", entries.first["platform"]

    specs = vault.specs
    assert_equal "x86_64-linux", specs.first.platform.to_s
    vault.close
  end

  # --- Gem with dependencies ---

  def test_gem_with_dependencies
    gem_path = build_gem("depgem", "1.0.0", dir: @gem_build_dir,
      dependencies: [["rake", ">= 13.0"]])
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)

    spec = vault.specs.first
    dep = spec.dependencies.find { |d| d.name == "rake" }
    assert dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
    vault.close
  end

  # --- gem_entries ---

  def test_gem_entries_excludes_data
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)

    entries = vault.gem_entries
    assert_equal 1, entries.length
    entry = entries.first
    assert entry["name"]
    assert entry["version"]
    assert entry["platform"]
    refute entry.key?("data"), "gem_entries should not include data blob"
    vault.close
  end

  # --- size ---

  def test_size_empty
    vault = Gemvault::Vault.new(@vault_path, create: true)
    assert_equal 0, vault.size
    vault.close
  end

  def test_size_after_add_and_remove
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.add(gem_path)
    assert_equal 1, vault.size
    vault.remove("foo", "1.0.0")
    assert_equal 0, vault.size
    vault.close
  end

  # --- close ---

  def test_close
    vault = Gemvault::Vault.new(@vault_path, create: true)
    vault.close
    # Double close should not raise
    vault.close
  end
end
