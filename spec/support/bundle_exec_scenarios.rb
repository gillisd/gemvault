module BundleExecScenarios
  REQUIRE_VAULT_GEM = %(bundle exec ruby -e "require 'vault_test_gem'; puts VaultTestGem::VERSION").freeze

  def bundle_exec_with_auto_installed_plugin
    podman_run(<<~SH)
      #{VaultedApp.auto_installed_bundle(setup: DistroRuby.regular_bundler + DistroRuby.without_system_gemvault)}
      #{REQUIRE_VAULT_GEM}
    SH
  end

  def bundle_exec_with_system_installed_plugin
    podman_run(<<~SH)
      #{TreeGems.build_preamble}
      #{DistroRuby.current_tree_as_system_gems}
      #{FixtureScript.preamble}
      #{VaultedApp.gemfile_vault_only}
      #{VaultedApp.vendored_install}
      #{REQUIRE_VAULT_GEM}
    SH
  end
end

RSpec.configure do |config|
  config.include BundleExecScenarios, :integration
end
