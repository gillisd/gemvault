require "test_helper"
require_relative "support/vault_source_test_case"

class VaultSourceModeTest < VaultSourceTestCase
  def test_local_mode_hides_gems_not_yet_installed
    source = vault_source_with_gem(name: "localmode", version: "1.0.0", subdir: "local_dir", remote: false)
    assert_empty source.fetch_gemspec_files
  end

  def test_remote_mode_advertises_gems_not_yet_installed
    source = vault_source_with_gem(name: "remotemode", version: "1.0.0", subdir: "remote_dir", remote: false)
    source.remote!
    assert_equal 1, source.fetch_gemspec_files.length
  end
end
