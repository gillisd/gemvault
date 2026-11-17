RSpec.describe "bundle install from a vault named by a gem source address", :integration do
  it "installs the gem and makes it loadable" do
    expect(install_from_addressed_vault).to succeed_showing("loaded 1.0.0")
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
    expect(configure_nothing_for_addressed_vault).to succeed_showing("Settings are listed").without("mirror", "MIRROR")
  end

  context "when Bundler predates the after-eval hook" do
    it "still installs the plugin" do
      expect(install_addressed_vault_on_image_bundler).to fail_showing("Installed plugin bundler-source-vault")
    end

    it "reports the vault address it could not reach" do
      expect(install_addressed_vault_on_image_bundler).to fail_showing("gemvault.invalid")
    end
  end

  context "when the Gemfile also names another gem source" do
    it "installs and loads gems from both" do
      expect(install_from_addressed_vault_beside_another_source)
        .to succeed_showing("loaded 1.0.0", "loaded command_kit")
    end

    it "locks each gem under its own source" do
      expect(install_from_addressed_vault_beside_another_source)
        .to succeed_showing("remote: https://gemvault.invalid/test.gemv/", "remote: http://127.0.0.1:8808/")
    end
  end

  context "when the vault sits in a subdirectory" do
    it "installs the gem and makes it loadable" do
      expect(install_from_nested_addressed_vault).to succeed_showing("loaded 1.0.0")
    end
  end

  context "when the project is moved after the plugin was installed" do
    it "installs the gem and makes it loadable" do
      expect(install_after_moving_the_project).to succeed_showing("loaded 1.0.0")
    end
  end

  context "when the vault changes after installing" do
    it "republishes it from under bundle exec" do
      expect(load_after_the_vault_changes).to succeed_showing("loaded 1.0.0")
    end
  end

  context "when the project path holds a space" do
    it "installs the gem and makes it loadable" do
      expect(install_from_addressed_vault_in_spaced_project).to succeed_showing("loaded 1.0.0")
    end
  end

  context "when the addressed vault is missing" do
    it "names the vault it could not find" do
      expect(install_from_absent_addressed_vault).to fail_showing("Could not find vault 'test.gemv'")
    end
  end
end
