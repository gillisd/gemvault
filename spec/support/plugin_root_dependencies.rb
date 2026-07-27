# Scenarios for loading the vault source when gemvault is already installed on
# the ambient GEM_PATH -- the state of any machine where `gem install gemvault`
# has run, which is everyone using the CLI.
#
# Bundler skips installing a plugin dependency that is already installed, so the
# plugin root ends up holding the shim alone. That stays invisible until the app
# bundle is populated: from then on Bundler restricts GEM_PATH to the plugin root
# and the bundle, the ambient copy falls out of scope, and loading the plugin
# fails.
#
# These scenarios deliberately leave gemvault installed system-wide. Removing it
# lets Bundler populate the plugin root and hides the defect.
module PluginRootDependencies
  SECOND_INSTALL_MARK = "===SECOND_INSTALL===".freeze
  REQUIRE_VAULT_GEM = %(bundle exec ruby -e "require 'vault_test_gem'; puts VaultTestGem::VERSION").freeze

  def install_twice_with_system_gemvault_present
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{FixtureScript.preamble}
      #{VaultedApp.gemfile_with_index}
      #{VaultedApp.vendored_install}
      echo #{SECOND_INSTALL_MARK}
      bundle install
    SH
  end

  def bundle_exec_with_system_gemvault_present
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{FixtureScript.preamble}
      #{VaultedApp.gemfile_with_index}
      #{VaultedApp.vendored_install}
      #{REQUIRE_VAULT_GEM}
    SH
  end

  def second_install_output(output)
    output.partition(SECOND_INSTALL_MARK).last
  end
end

RSpec.configure do |config|
  config.include PluginRootDependencies, :integration
end
