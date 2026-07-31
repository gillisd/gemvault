require "test_helper"
require_relative "support/cli_test_case"

class CLINewTest < CLITestCase
  def test_new_creates_vault
    assert_equal 0, run_cli("new", "myvault")
    assert_path_exists @tmpdir / "myvault.gemv"
    assert_match(/Created myvault\.gemv/, @stdout)
  end

  def test_new_appends_gemv_extension
    run_cli("new", "test")
    assert_path_exists @tmpdir / "test.gemv"
  end

  def test_new_preserves_gemv_extension
    run_cli("new", "test.gemv")
    assert_path_exists @tmpdir / "test.gemv"
  end

  def test_new_errors_on_existing
    run_cli("new", "dup")
    assert_equal 1, run_cli("new", "dup")
    assert_match(/already exists/, @stderr)
  end

  def test_new_errors_without_name
    assert_equal 1, run_cli("new")
  end
end
