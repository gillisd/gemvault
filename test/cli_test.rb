# frozen_string_literal: true

require "test_helper"
require "gemvault/cli"

class CLITest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Dir.mktmpdir("gemvault_cli_test")
    @gem_build_dir = File.join(@tmpdir, "gems")
    FileUtils.mkdir_p(@gem_build_dir)
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  # --- new ---

  def test_new_creates_vault
    assert_equal 0, run_cli("new", "myvault")
    assert_path_exists File.join(@tmpdir, "myvault.gemv")
    assert_match(/Created myvault\.gemv/, @stdout)
  end

  def test_new_appends_gemv_extension
    run_cli("new", "test")
    assert_path_exists File.join(@tmpdir, "test.gemv")
  end

  def test_new_preserves_gemv_extension
    run_cli("new", "test.gemv")
    assert_path_exists File.join(@tmpdir, "test.gemv")
  end

  def test_new_errors_on_existing
    run_cli("new", "dup")
    assert_equal 1, run_cli("new", "dup")
    assert_match(/already exists/, @stderr)
  end

  def test_new_errors_without_name
    assert_equal 1, run_cli("new")
    assert_match(/Usage/, @stderr)
  end

  # --- add ---

  def test_add_single_gem
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    assert_equal 0, run_cli("add", "test.gemv", gem_path)
    assert_match(/Added foo-1\.0\.0/, @stdout)
  end

  def test_add_multiple_gems
    gem1 = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    dir2 = File.join(@gem_build_dir, "bar_dir")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("bar", "2.0.0", dir: dir2)
    run_cli("new", "test")
    assert_equal 0, run_cli("add", "test.gemv", gem1, gem2)
    assert_match(/Added foo-1\.0\.0/, @stdout)
    assert_match(/Added bar-2\.0\.0/, @stdout)
  end

  def test_add_errors_on_invalid_gem
    bad_gem = File.join(@tmpdir, "bad.gem")
    File.write(bad_gem, "not a gem")
    run_cli("new", "test")
    assert_equal 1, run_cli("add", "test.gemv", bad_gem)
    assert_match(/Error/, @stderr)
  end

  def test_add_errors_without_args
    assert_equal 1, run_cli("add")
    assert_match(/Usage/, @stderr)
  end

  def test_add_errors_without_gem_args
    run_cli("new", "test")
    assert_equal 1, run_cli("add", "test.gemv")
    assert_match(/Usage/, @stderr)
  end

  def test_add_duplicate_gem_errors
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)
    assert_equal 1, run_cli("add", "test.gemv", gem_path)
    assert_match(/already in vault/, @stderr)
  end

  def test_add_to_nonexistent_vault_errors
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    assert_equal 1, run_cli("add", "nope.gemv", gem_path)
    assert_match(/Error/, @stderr)
  end

  # --- list ---

  def test_list_empty
    run_cli("new", "test")
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(/empty/, @stdout)
  end

  def test_list_with_gems
    gem1 = build_gem("alpha", "1.0.0", dir: @gem_build_dir)
    dir2 = File.join(@gem_build_dir, "beta_dir")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("beta", "2.0.0", dir: dir2)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(/alpha-1\.0\.0/, @stdout)
    assert_match(/beta-2\.0\.0/, @stdout)
  end

  def test_list_platform_gem
    gem_path = build_gem("native", "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux")
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(/native-1\.0\.0 \(x86_64-linux\)/, @stdout)
  end

  def test_list_errors_without_vault
    assert_equal 1, run_cli("list")
    assert_match(/Usage/, @stderr)
  end

  def test_list_nonexistent_vault_errors
    assert_equal 1, run_cli("list", "nope.gemv")
    assert_match(/Error/, @stderr)
  end

  # --- remove ---

  def test_remove_specific_version
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)
    assert_equal 0, run_cli("remove", "test.gemv", "foo", "1.0.0")
    assert_match(/Removed 1/, @stdout)
  end

  def test_remove_all_versions
    gem1 = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    dir2 = File.join(@gem_build_dir, "v2")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("foo", "2.0.0", dir: dir2)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)
    assert_equal 0, run_cli("remove", "test.gemv", "foo")
    assert_match(/Removed 2/, @stdout)
  end

  def test_remove_nonexistent_errors
    run_cli("new", "test")
    assert_equal 1, run_cli("remove", "test.gemv", "nope")
    assert_match(/No matching gem/, @stderr)
  end

  def test_remove_errors_without_args
    assert_equal 1, run_cli("remove")
    assert_match(/Usage/, @stderr)
  end

  def test_remove_from_nonexistent_vault_errors
    assert_equal 1, run_cli("remove", "nope.gemv", "foo")
    assert_match(/Error/, @stderr)
  end

  # --- extract ---

  def test_extract_produces_valid_gem
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    original = File.binread(gem_path)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    output_dir = File.join(@tmpdir, "output")
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "1.0.0", "-o", output_dir)
    assert_match(/Extracted foo-1\.0\.0\.gem/, @stdout)

    extracted = File.binread(File.join(output_dir, "foo-1.0.0.gem"))
    assert_equal original, extracted
  end

  def test_extract_output_flag
    gem_path = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    output_dir = File.join(@tmpdir, "custom_out")
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "1.0.0", "--output", output_dir)
    assert_path_exists File.join(output_dir, "foo-1.0.0.gem")
  end

  def test_extract_all_versions
    gem1 = build_gem("foo", "1.0.0", dir: @gem_build_dir)
    dir2 = File.join(@gem_build_dir, "v2")
    FileUtils.mkdir_p(dir2)
    gem2 = build_gem("foo", "2.0.0", dir: dir2)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)

    output_dir = File.join(@tmpdir, "output")
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "-o", output_dir)
    assert_path_exists File.join(output_dir, "foo-1.0.0.gem")
    assert_path_exists File.join(output_dir, "foo-2.0.0.gem")
  end

  def test_extract_nonexistent_gem_errors
    run_cli("new", "test")
    assert_equal 1, run_cli("extract", "test.gemv", "nope")
    assert_match(/No gem named/, @stderr)
  end

  def test_extract_errors_without_args
    assert_equal 1, run_cli("extract")
    assert_match(/Usage/, @stderr)
  end

  def test_extract_from_nonexistent_vault_errors
    assert_equal 1, run_cli("extract", "nope.gemv", "foo")
    assert_match(/Error/, @stderr)
  end

  # --- version ---

  def test_version
    assert_equal 0, run_cli("version")
    assert_match(/gemvault #{Gemvault::VERSION}/, @stdout)
  end

  # --- help ---

  def test_help
    assert_equal 0, run_cli("help")
    assert_match(/Usage/, @stdout)
    assert_match(/Commands/, @stdout)
  end

  def test_no_command_shows_help
    assert_equal 0, run_cli
    assert_match(/Usage/, @stdout)
  end

  # --- unknown command ---

  def test_unknown_command
    assert_equal 1, run_cli("bogus")
    assert_match(/Unknown command/, @stderr)
  end

  private

  def run_cli(*args)
    result = nil
    @stdout, @stderr = capture_io do
      result = Gemvault::CLI.run(args.map(&:to_s))
    end
    result
  end
end
