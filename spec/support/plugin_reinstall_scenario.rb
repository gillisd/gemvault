module PluginReinstallScenario
  SECOND_INSTALL_MARK = "===SECOND_INSTALL===".freeze

  def bundle_install_twice_with_auto_installed_plugin
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{FixtureScript.preamble}
      #{DistroRuby.without_system_gemvault}
      #{VaultedApp.gemfile_with_index}
      #{VaultedApp.vendored_install}
      echo #{SECOND_INSTALL_MARK}
      bundle install
    SH
  end
end

RSpec.configure do |config|
  config.include PluginReinstallScenario, :integration
end
