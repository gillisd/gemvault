RSpec.describe "bundle install from a vault named by a gem source address", :integration do
  it "installs the gem and makes it loadable" do
    expect(install_from_addressed_vault).to succeed_showing("1.0.0")
  end

  it "locks the gem under an ordinary gem source" do
    expect(lock_addressed_vault).to succeed_showing("remote: https://gemvault.invalid/test.gemv/")
  end

  it "locks the version the vault holds" do
    expect(lock_addressed_vault).to succeed_showing("vault_test_gem (1.0.0)")
  end

  it "writes no plugin source into the lockfile" do
    expect(lock_addressed_vault).to succeed.without("PLUGIN SOURCE")
  end

  it "produces an idempotent lockfile" do
    expect(install_addressed_vault_twice).to succeed
  end

  it "leaves no mirror in any Bundler config" do
    expect(configure_nothing_for_addressed_vault).to succeed.without("mirror", "MIRROR")
  end

  context "when Bundler predates the after-eval hook" do
    it "still installs the plugin" do
      expect(install_addressed_vault_on_image_bundler).to fail_showing("Installed plugin bundler-source-vault")
    end

    it "reports the vault address it could not reach" do
      expect(install_addressed_vault_on_image_bundler).to fail_showing("gemvault.invalid")
    end
  end

  context "when the project path holds a space" do
    it "installs the gem and makes it loadable" do
      expect(install_from_addressed_vault_in_spaced_project).to succeed_showing("1.0.0")
    end
  end

  context "when the addressed vault is missing" do
    it "names the vault it could not find" do
      output, = install_from_absent_addressed_vault
      expect(output).to include("Could not find vault 'test.gemv'")
    end
  end
end
