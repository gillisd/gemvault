# The reporter's flow for issue #25: a project locking an older json than the
# machine's newest, bundled against a vault source with gemvault installed
# system-wide. Anything on gemvault's load path that requires json detonates
# check_for_activated_spec! in the exec'd process, so the scenario passes only
# when the bundle activates exactly the json the lockfile names.
module JsonSkewScenarios
  SHOW_BUNDLED_JSON = <<~SH.freeze
    bundle exec ruby -e "require 'vault_test_gem'; require 'json'; puts VaultTestGem::VERSION; print 'activated json '; puts Gem.loaded_specs['json'].version"
  SH

  def bundle_exec_with_a_newer_json_installed
    podman_run(<<~SH)
      set -e
      #{JsonVersionSkew.older_in_index}
      #{GemIndex.serve_preamble}
      #{DistroRuby.current_tree_as_system_gems}
      #{JsonVersionSkew.newer_installed}
      #{JsonVersionSkew.resolved_through_activation}
      #{FixtureScript.preamble}
      #{json_locking_gemfile}
      #{VaultedApp.vendored_install}
      #{SHOW_BUNDLED_JSON}
    SH
  end

  def json_locking_gemfile
    <<~SH
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      #{GemIndex.source_line}

      gem "json", "#{JsonVersionSkew::LOCKED}"

      source "$WORKDIR/test.gemv", type: :vault do
        gem "vault_test_gem"
      end
      GEMFILE
    SH
  end
end

RSpec.configure do |config|
  config.include JsonSkewScenarios, :integration
end
