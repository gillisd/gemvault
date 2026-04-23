RSpec.describe "gem install with vault source", :integration do
  def gem_install_script(gem_name, vault_flags, assertions)
    preamble = FixtureScript.preamble(gems: [[gem_name, "1.0.0"]])
    <<~SH
      #{preamble}
      SYSTEM_GEM_PATH=$(ruby -e 'puts Gem.path.join(":")')
      export GEM_HOME=$(mktemp -d)
      export GEM_PATH="$GEM_HOME:$SYSTEM_GEM_PATH"
      gem install #{vault_flags} --no-document #{gem_name}
      #{assertions}
    SH
  end

  it "installs a gem and makes it loadable" do
    output, status = podman_run(gem_install_script(
      "vault_container_test",
      "--source $WORKDIR/test.gemv",
      'ruby -e "require \'vault_container_test\'; puts VaultContainerTest::VERSION"',
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end

  it "shows vault messages with --verbose" do
    output, status = podman_run(gem_install_script(
      "vault_verbose",
      "--verbose --source $WORKDIR/test.gemv",
      "true",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/Loading .* specs from vault at/)
  end

  it "accepts a file:// URI as the source" do
    output, status = podman_run(gem_install_script(
      "vault_fileuri",
      "--source file://$WORKDIR/test.gemv",
      "true",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/installed vault_fileuri/i)
  end

  it "accepts a vault:// URI with an absolute path" do
    output, status = podman_run(gem_install_script(
      "vault_uri_abs",
      "--source vault://$WORKDIR/test.gemv",
      "true",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to match(/installed vault_uri_abs/i)
  end
end
