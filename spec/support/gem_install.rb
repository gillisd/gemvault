module GemInstall
  LOADING_SPECS_MESSAGE = /Loading .* specs from vault at/

  def run_gem_install(gem_name, vault_flags, assertions)
    podman_run(gem_install_script(gem_name, vault_flags, assertions))
  end

  def install_and_require_gem
    run_gem_install(
      "vault_container_test",
      "--source $WORKDIR/test.gemv",
      'ruby -e "require \'vault_container_test\'; puts VaultContainerTest::VERSION"',
    )
  end

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
end

RSpec.configure do |config|
  config.include GemInstall, :integration
end
