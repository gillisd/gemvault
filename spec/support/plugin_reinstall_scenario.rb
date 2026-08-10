module PluginReinstallScenario
  SECOND_INSTALL_MARK = "===SECOND_INSTALL===".freeze

  def bundle_install_twice_with_auto_installed_plugin
    podman_run(<<~SH)
      #{VaultedApp.auto_installed_bundle(setup: DistroRuby.without_system_gemvault)}
      echo #{SECOND_INSTALL_MARK}
      bundle install
    SH
  end
end

RSpec.configure do |config|
  config.include PluginReinstallScenario, :integration
end
