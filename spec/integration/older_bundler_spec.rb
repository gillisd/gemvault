RSpec.describe "bundle install from a plugin source on a Bundler without the after-eval hook", :integration do
  it "runs on that Bundler" do
    expect(install_into_vendor_path_on_older_bundler).to succeed_showing("running bundler 4.0.23")
  end

  it "installs the gem and makes it loadable" do
    expect(install_into_vendor_path_on_older_bundler).to succeed_showing("loaded 1.0.0")
  end

  context "when the bundle is installed a second time" do
    it "installs the gem and makes it loadable" do
      expect(install_twice_on_older_bundler).to succeed_showing("loaded 1.0.0")
    end

    it "loads gemvault once" do
      expect(install_twice_on_older_bundler).to succeed.without("already initialized constant")
    end
  end

  context "when the lockfile is committed and the bundle is frozen" do
    it "installs the gem and makes it loadable" do
      expect(install_frozen_from_a_committed_lockfile_on_older_bundler).to succeed_showing("loaded 1.0.0")
    end
  end

  context "when the project then moves to a newer Bundler and addresses its vault" do
    it "leaves the vault unredirected" do
      expect(address_the_vault_after_leaving_older_bundler("bundle plugin install bundler-source-vault"))
        .to fail_showing("now running bundler 4.1.0", "Could not reach host gemvault.invalid")
    end

    context "when the plugin directory is deleted first" do
      it "installs the gem and makes it loadable" do
        recovery = "rm -r .bundle/plugin\nbundle plugin install bundler-source-vault"

        expect(address_the_vault_after_leaving_older_bundler(recovery)).to succeed_showing("loaded 1.0.0")
      end
    end
  end
end
