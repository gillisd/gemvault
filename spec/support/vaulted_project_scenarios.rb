module VaultedProjectScenarios
  def install_vaulted_project(machine:, setup:, steps:)
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{machine}
      #{FixtureScript.preamble(gems: VaultedProject::VAULT_GEMS)}
      #{FixtureScript.additional_vault(vault: VaultedProject::SECOND_VAULT, gems: VaultedProject::SECOND_VAULT_GEMS)}
      cd $WORKDIR
      #{VaultedProject.gemfile_declaring(vaulted: [VaultedProject::VAULTED_GEM])}
      #{setup}
      bundle install
      #{steps}
      bundle list
    SH
  end

  def listed_gems(output)
    output.scan(/^\s*\*\s+(\S+)/).flatten
  end

  def gems_missing_from(output, expected)
    expected - listed_gems(output)
  end
end

RSpec.configure do |config|
  config.include VaultedProjectScenarios, :integration
end
