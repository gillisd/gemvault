require_relative "spec_helper"

RSpec.describe "gem install with vault source" do
  before do
    install_gemvault!
    @workdir = Pathname(Dir.mktmpdir("gem_install_spec"))
    @gem_build_dir = @workdir / "gems"
    @gem_build_dir.mkpath
    @gem_home = @workdir / "gem_home"
    @gem_home.mkpath
  end

  after { @workdir.rmtree }

  it "installs a gem and makes it loadable" do
    gem_path = build_gem("vault_container_test", "1.0.0", dir: @gem_build_dir,
      files: {"lib/vault_container_test.rb" => 'module VaultContainerTest; VERSION = "1.0.0"; end'})

    vault_path = create_vault(@workdir / "test.gemv", gem_path)

    env = gem_env_for(@gem_home)
    output, status = Open3.capture2e(
      env,
      "gem", "install", "--source", vault_path.to_s, "--no-document", "vault_container_test",
    )

    expect(status).to be_success
    expect(output).to match(/installed vault_container_test/i)

    specs = Dir.glob(@gem_home / "specifications" / "vault_container_test-1.0.0.gemspec")
    expect(specs).not_to be_empty

    load_output, load_status = Open3.capture2e(
      env,
      "ruby", "-e", 'require "vault_container_test"; puts VaultContainerTest::VERSION',
    )
    expect(load_status).to be_success
    expect(load_output).to match(/1\.0\.0/)
  end

  it "shows vault messages with --verbose" do
    gem_path = build_gem("vault_verbose", "1.0.0", dir: @gem_build_dir,
      files: {"lib/vault_verbose.rb" => 'module VaultVerbose; VERSION = "1.0.0"; end'})

    vault_path = create_vault(@workdir / "verbose.gemv", gem_path)

    env = gem_env_for(@gem_home)
    output, status = Open3.capture2e(
      env,
      "gem", "install", "--verbose", "--source", vault_path.to_s,
      "--no-document", "vault_verbose",
    )

    expect(status).to be_success
    expect(output).to match(/Loading .* specs from vault at/)
    expect(output).to match(/Extracting vault_verbose-1\.0\.0\.gem from vault at/)
  end

  it "accepts a file:// URI as the source" do
    gem_path = build_gem("vault_fileuri", "1.0.0", dir: @gem_build_dir,
      files: {"lib/vault_fileuri.rb" => 'module VaultFileuri; VERSION = "1.0.0"; end'})

    vault_path = create_vault(@workdir / "fileuri.gemv", gem_path)

    env = gem_env_for(@gem_home)
    output, status = Open3.capture2e(
      env,
      "gem", "install", "--source", "file://#{vault_path}",
      "--no-document", "vault_fileuri",
    )

    expect(status).to be_success
    expect(output).to match(/installed vault_fileuri/i)
  end
end
