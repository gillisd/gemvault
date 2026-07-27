module VaultedProjectScenarios
  # A scenario runs `bundle install` up to three times before the closing
  # `bundle list`, and installer output carries gem names too. The mark keeps
  # the assertions reading the listing rather than the whole transcript.
  BUNDLE_LIST_MARK = "===BUNDLE_LIST===".freeze

  def install_vaulted_project(machine:, setup:, steps:)
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{machine}
      #{FixtureScript.preamble(gems: VaultedProject::VAULT_GEMS)}
      #{FixtureScript.additional_vault(vault: VaultedProject::SECOND_VAULT, gems: VaultedProject::SECOND_VAULT_GEMS)}
      cd $WORKDIR
      #{VaultedGemfile.declaring(vaulted: [VaultedProject::VAULTED_GEM])}
      #{setup}
      bundle install
      #{steps}
      echo #{BUNDLE_LIST_MARK}
      bundle list
    SH
  end

  def listed_gems(output)
    output.partition(BUNDLE_LIST_MARK).last.scan(/^\s*\*\s+(\S+)/).flatten
  end

  def gems_missing_from(output, expected)
    expected - listed_gems(output)
  end
end

RSpec.configure do |config|
  config.include VaultedProjectScenarios, :integration
end
