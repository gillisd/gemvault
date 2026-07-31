require "test_helper"
require_relative "support/cli_test_case"

class CLIListTest < CLITestCase
  PLATFORM_LISTING_PATTERN = /native-1\.0\.0 \(x86_64-linux\)/

  def test_list_empty
    run_cli("new", "test")
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(/empty/, @stdout)
  end

  def test_list_with_gems
    gem1 = build_gem(name: "alpha", version: "1.0.0", dir: @gem_build_dir)
    dir2 = @gem_build_dir / "beta_dir"
    dir2.mkpath
    gem2 = build_gem(name: "beta", version: "2.0.0", dir: dir2)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(/alpha-1\.0\.0/, @stdout)
    assert_match(/beta-2\.0\.0/, @stdout)
  end

  def test_list_platform_gem
    gem_path = build_gem(name: "native", version: "1.0.0", dir: @gem_build_dir, platform: "x86_64-linux")
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)
    assert_equal 0, run_cli("list", "test.gemv")
    assert_match(PLATFORM_LISTING_PATTERN, @stdout)
  end

  def test_list_errors_without_vault
    assert_equal 1, run_cli("list")
  end

  def test_list_nonexistent_vault_errors
    assert_equal 1, run_cli("list", "nope.gemv")
    refute_empty @stderr
  end
end
