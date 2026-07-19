module VaultUriScenario
  def list_vault_through_uri(scheme)
    podman_run(<<~SH)
      #{TreeGems.build_preamble}
      #{DistroRuby.current_tree_as_system_gems}
      #{FixtureScript.preamble(gems: [["uri_gem", "1.0.0"]])}
      gemvault list #{scheme}$WORKDIR/test.gemv
    SH
  end
end

RSpec.configure do |config|
  config.include VaultUriScenario, :integration
end
