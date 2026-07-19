module VaultUriScenario
  def list_vault_through_uri(scheme)
    podman_run(<<~SH)
      #{uri_vault_preamble}
      gemvault list #{scheme}$WORKDIR/test.gemv
    SH
  end

  def upgrade_vault_through_uri(scheme)
    podman_run(<<~SH)
      #{uri_vault_preamble}
      gemvault upgrade #{scheme}$WORKDIR/test.gemv
    SH
  end

  private

  def uri_vault_preamble
    <<~SH
      #{TreeGems.build_preamble}
      #{DistroRuby.current_tree_as_system_gems}
      #{FixtureScript.preamble(gems: [["uri_gem", "1.0.0"]])}
    SH
  end
end

RSpec.configure do |config|
  config.include VaultUriScenario, :integration
end
