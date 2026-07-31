RSpec.describe "bundle exec against a vault-sourced bundle", :integration do
  context "when the plugin was auto-installed from a gem index and bundler is a regular gem" do
    it "loads the vault gem" do
      expect(bundle_exec_with_auto_installed_plugin).to succeed_showing("1.0.0")
    end
  end

  context "when gemvault and the shim are installed as system gems" do
    it "loads the vault gem" do
      expect(bundle_exec_with_system_installed_plugin).to succeed_showing("1.0.0")
    end
  end
end
