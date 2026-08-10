require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"

class RubygemsSourceVaultUriTest < Minitest::Test
  include GemvaultTestHelper

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("gemvault_uri_test"))
    @vault_path = @tmpdir / "test.gemv"
  end

  def test_file_uri_strips_scheme
    assert_equal @vault_path.expand_path.to_s, source_for("file://").path
  end

  def test_file_uri_equals_plain_path
    assert_equal source_for(""), source_for("file://")
  end

  def test_vault_uri_strips_scheme
    assert_equal @vault_path.expand_path.to_s, source_for("vault://").path
  end

  def test_vault_uri_equals_plain_path
    assert_equal source_for(""), source_for("vault://")
  end

  private

  def source_for(scheme)
    Gem::Source::Vault.new("#{scheme}#{@vault_path}")
  end
end
