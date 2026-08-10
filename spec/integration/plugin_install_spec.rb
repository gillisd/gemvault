RSpec.describe "bundle plugin install bundler-source-vault", :integration do
  context "when run in a project configured with path: vendor" do
    it "installs the plugin on the first attempt" do
      expect(install_plugin_in_project_with_vendor_path).to succeed_showing("Installed plugin bundler-source-vault")
    end
  end

  context "when run outside any project" do
    it "installs the plugin into the global plugin root on the first attempt" do
      expect(install_plugin_outside_any_project).to succeed_showing("Installed plugin bundler-source-vault")
    end
  end

  context "when bundler is a regular gem, as on distro rubies" do
    it "installs the plugin on the first attempt" do
      expect(install_plugin_with_distro_bundler).to succeed_showing("Installed plugin bundler-source-vault")
    end
  end
end
