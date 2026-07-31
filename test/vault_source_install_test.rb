require "test_helper"
require_relative "support/vault_source_test_case"

class VaultSourceInstallTest < VaultSourceTestCase
  def test_install_extracts_to_bundle_path
    source, spec = prepared_alpha
    refute_nil spec, "Expected to find alpha spec"

    source.install(spec)

    gem_dir = Pathname(Bundler.bundle_path) / "gems" / "alpha-1.0.0"
    assert_path_exists gem_dir
  end

  def test_install_sets_full_gem_path
    source, spec = prepared_alpha
    source.install(spec)

    refute_nil spec.full_gem_path
    assert_path_exists spec.full_gem_path
  end

  def test_install_sets_loaded_from
    source, spec = prepared_alpha
    source.install(spec)

    refute_nil spec.loaded_from
    assert_path_exists spec.loaded_from
  end

  def test_install_skips_when_already_installed
    out, spec = reinstalled_output
    refute_match(/Installing/, out, "Expected skip on second install, but got Installing output")
    assert_equal File.join(Bundler.bundle_path, "gems", spec.full_name), spec.full_gem_path
    assert_path_exists spec.loaded_from
  end

  def test_install_force_reinstalls_when_already_installed
    out, = reinstalled_output(force: true)
    assert_match(/Installing/, out, "Expected force reinstall to print Installing")
  end

  private

  def reinstalled_output(force: false)
    source, spec = prepared_alpha
    source.install(spec)
    [capture_reinstall_output(source: source, spec: spec, force: force), spec]
  end

  def prepared_alpha
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha]
    [source, find_spec(source: source, name: "alpha")]
  end

  def capture_reinstall_output(source:, spec:, force: false)
    out, _err = capture_io do
      Bundler.ui = Bundler::UI::Shell.new
      source.install(spec, force: force)
    end
    out
  end
end
