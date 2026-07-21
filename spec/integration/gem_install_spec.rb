RSpec.describe "gem install with vault source", :integration do
  it "installs a gem and makes it loadable", :aggregate_failures do
    output, status = install_and_require_gem
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end

  it "shows vault messages with --verbose", :aggregate_failures do
    output, status = run_gem_install(gem_name: "vault_verbose", vault_flags: "--verbose --source $WORKDIR/test.gemv",
                                     assertions: "true")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(GemInstall::LOADING_SPECS_MESSAGE)
  end

  it "accepts a file:// URI as the source", :aggregate_failures do
    output, status = run_gem_install(gem_name: "vault_fileuri", vault_flags: "--source file://$WORKDIR/test.gemv",
                                     assertions: "true")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/installed vault_fileuri/i)
  end

  it "accepts a vault:// URI with an absolute path", :aggregate_failures do
    output, status = run_gem_install(gem_name: "vault_uri_abs", vault_flags: "--source vault://$WORKDIR/test.gemv",
                                     assertions: "true")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/installed vault_uri_abs/i)
  end

  context "when the vault's only version carries a non-numeric suffix" do
    it "treats it as a prerelease and installs it with --pre", :aggregate_failures do
      output, status = run_gem_install(gem_name: "suffix_gem", version: "0.2.1.patch1",
                                       vault_flags: "--pre --source $WORKDIR/test.gemv", assertions: "true")
      expect(status).to be_success, "Failed:\n#{output}"
      expect(output).to match(GemInstall::INSTALLED_SUFFIXED_VERSION)
    end
  end
end
