module GemInstall
  LOADING_SPECS_MESSAGE = /Loading .* specs from vault at/
  INSTALLED_SUFFIXED_VERSION = /installed suffix_gem-0\.2\.1\.patch1/i

  def run_gem_install(gem_name:, vault_flags:, assertions:, version: "1.0.0")
    podman_run(gem_install_script(gem_name: gem_name, vault_flags: vault_flags, assertions: assertions,
                                  version: version))
  end

  def install_and_require_gem
    run_gem_install(
      gem_name: "vault_container_test",
      vault_flags: "--source $WORKDIR/test.gemv",
      assertions: 'ruby -e "require \'vault_container_test\'; puts VaultContainerTest::VERSION"',
    )
  end

  def gem_install_script(gem_name:, vault_flags:, assertions:, version: "1.0.0")
    preamble = FixtureScript.preamble(gems: [[gem_name, version]])
    <<~SH
      #{preamble}
      SYSTEM_GEM_PATH=$(ruby -e 'puts Gem.path.join(":")')
      export GEM_HOME=$(mktemp -d)
      export GEM_PATH="$GEM_HOME:$SYSTEM_GEM_PATH"
      gem install #{vault_flags} --no-document #{gem_name}
      #{assertions}
    SH
  end
end

RSpec.configure do |config|
  config.include GemInstall, :integration
end
