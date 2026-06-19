RSpec.describe "gem install with vault source", :integration do
  it "installs a gem and makes it loadable", :aggregate_failures do
    output, status = install_and_require_gem
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end

  it "shows vault messages with --verbose", :aggregate_failures do
    output, status = run_gem_install("vault_verbose", "--verbose --source $WORKDIR/test.gemv", "true")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(GemInstall::LOADING_SPECS_MESSAGE)
  end

  it "accepts a file:// URI as the source", :aggregate_failures do
    output, status = run_gem_install("vault_fileuri", "--source file://$WORKDIR/test.gemv", "true")
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/installed vault_fileuri/i)
  end
end
