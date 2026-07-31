require "test_helper"
require_relative "support/cli_test_case"

class CLIExtractTest < CLITestCase
  EXTRACTED_GEM_PATTERN = /Extracted foo-1\.0\.0\.gem/

  def test_extract_produces_valid_gem
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    original = gem_path.binread
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    output_dir = @tmpdir / "output"
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "1.0.0", "-o", output_dir)
    assert_match(EXTRACTED_GEM_PATTERN, @stdout)

    extracted = (output_dir / "foo-1.0.0.gem").binread
    assert_equal original, extracted
  end

  def test_extract_output_flag
    gem_path = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem_path)

    output_dir = @tmpdir / "custom_out"
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "1.0.0", "--output", output_dir)
    assert_path_exists output_dir / "foo-1.0.0.gem"
  end

  def test_extract_all_versions
    gem1 = build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
    dir2 = @gem_build_dir / "v2"
    dir2.mkpath
    gem2 = build_gem(name: "foo", version: "2.0.0", dir: dir2)
    run_cli("new", "test")
    run_cli("add", "test.gemv", gem1, gem2)

    output_dir = @tmpdir / "output"
    assert_equal 0, run_cli("extract", "test.gemv", "foo", "-o", output_dir)
    assert_path_exists output_dir / "foo-1.0.0.gem"
    assert_path_exists output_dir / "foo-2.0.0.gem"
  end

  def test_extract_nonexistent_gem_errors
    run_cli("new", "test")
    assert_equal 1, run_cli("extract", "test.gemv", "nope")
    assert_match(/No gem named/, @stderr)
  end

  def test_extract_errors_without_args
    assert_equal 1, run_cli("extract")
  end

  def test_extract_from_nonexistent_vault_errors
    assert_equal 1, run_cli("extract", "nope.gemv", "foo")
    refute_empty @stderr
  end
end
