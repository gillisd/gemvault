require "test_helper"
require_relative "support/cli_test_case"

class CLIAddTest < CLITestCase
  def test_add_single_gem
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")

    assert_equal 0, run_cli("add", "test.gemv", gem_path)
    assert_match(/Added foo-1\.0\.0/, @stdout)
  end

  def test_add_multiple_gems
    gem1 = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    gem2 = build_subdir_gem(name: "bar", version: "2.0.0", subdir: "bar_dir")
    run_cli("new", "test")

    assert_equal 0, run_cli("add", "test.gemv", gem1, gem2)
    assert_match(/Added foo-1\.0\.0/, @stdout)
    assert_match(/Added bar-2\.0\.0/, @stdout)
  end

  def test_add_errors_on_invalid_gem
    bad_gem = @tmpdir / "bad.gem"
    bad_gem.write("not a gem")
    run_cli("new", "test")

    assert_equal 1, run_cli("add", "test.gemv", bad_gem)
    refute_empty @stderr
  end

  def test_add_errors_without_args
    assert_equal 1, run_cli("add")
  end

  def test_add_errors_without_gem_args
    run_cli("new", "test")

    assert_equal 1, run_cli("add", "test.gemv")
  end

  def test_add_duplicate_gem_errors
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    assert_equal 1, run_cli("add", "test.gemv", gem_path)
    assert_match(/already in vault/, @stderr)
  end

  def test_add_to_nonexistent_vault_errors
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)

    assert_equal 1, run_cli("add", "nope.gemv", gem_path)
    refute_empty @stderr
  end
end
