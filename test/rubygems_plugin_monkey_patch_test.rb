require "test_helper"
require "rubygems/command"
require "rubygems/resolver"
require "rubygems_plugin"
require "rubygems/resolver/vault_set"

class RubygemsPluginMonkeyPatchTest < Minitest::Test
  def test_local_remote_options_has_vault_uri_patch
    assert_includes Gem::LocalRemoteOptions.ancestors, Gemvault::AcceptVaultURI
  end

  def test_local_remote_options_has_vault_source_option_patch
    assert_includes Gem::LocalRemoteOptions.ancestors, Gemvault::AddVaultSourceOption
  end

  def test_source_list_creates_vault_source_for_gemv
    list = Gem::SourceList.new
    src = list << "/path/to/test.gemv"
    assert_instance_of Gem::Source::Vault, src
    assert_equal 1, list.sources.size
  end

  def test_source_list_creates_normal_source_for_url
    list = Gem::SourceList.new
    src = list << "https://rubygems.org/"
    assert_instance_of Gem::Source, src
  end

  def test_source_list_deduplicates_gemv
    list = Gem::SourceList.new
    list << "/path/to/test.gemv"
    list << "/path/to/test.gemv"
    assert_equal 1, list.sources.size
  end
end
