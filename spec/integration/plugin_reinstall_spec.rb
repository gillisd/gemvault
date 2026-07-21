RSpec.describe "repeated bundle install with a vault source", :integration do
  it "does not reinstall the plugin gems on the second run", :aggregate_failures do
    pending "upstream: Bundler::Plugin.gemfile_install re-resolves and reinstalls Gemfile plugins on every run"
    output, status = bundle_install_twice_with_auto_installed_plugin
    expect(status).to be_success, "bundle install failed:\n#{output}"
    expect(output.partition(PluginReinstallScenario::SECOND_INSTALL_MARK).last).not_to include("Installing gemvault")
  end
end
