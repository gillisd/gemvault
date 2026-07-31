require "test_helper"
require_relative "support/cli_test_case"

class CLIRemoveTest < CLITestCase
  def test_remove_specific_version
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    assert_equal 0, run_cli("remove", "test.gemv", "foo", "1.0.0")
    assert_match(/Removed 1/, @stdout)
  end

  def test_remove_all_versions
    gem1 = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    gem2 = build_subdir_gem(name: "foo", version: "2.0.0", subdir: "v2")
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)

    assert_equal 0, run_cli("remove", "test.gemv", "foo")
    assert_match(/Removed 2/, @stdout)
  end

  def test_remove_combined_name_version_subprocess_smoke
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    assert_equal 0, run_cli("remove", "test.gemv", "foo-1.0.0")
    assert_match(/Removed 1/, @stdout)
  end

  def test_remove_nonexistent_errors
    run_cli("new", "test")

    assert_equal 1, run_cli("remove", "test.gemv", "nope")
    assert_match(/No matching gem/, @stderr)
  end

  def test_remove_errors_without_args
    assert_equal 1, run_cli("remove")
  end

  def test_remove_from_nonexistent_vault_errors
    assert_equal 1, run_cli("remove", "nope.gemv", "foo")
    refute_empty @stderr
  end
end
