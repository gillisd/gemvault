module UpgradeCommand
  def run_upgrade(upgrade_args: "", followup: "")
    podman_run(<<~SH)
      #{dbvault_preamble}
      gemvault upgrade $V #{upgrade_args}
      #{followup}
    SH
  end

  def run_upgrade_on_tarvault(gems:, upgrade_args: "")
    podman_run(<<~SH)
      #{FixtureScript.preamble(gems:)}
      gemvault upgrade $WORKDIR/test.gemv #{upgrade_args}
    SH
  end

  def run_on_legacy_tarvault(command:)
    podman_run(<<~SH)
      #{legacy_tarvault_preamble}
      #{command}
    SH
  end

  # Copies the committed format-2 vault fixture (manifest.json index) into the
  # container, standing in for a vault a user made with gemvault 0.2.x, and
  # builds a gem at $NEW_GEM so an add is refused for being read-only rather
  # than for naming a file that is not there.
  def legacy_tarvault_preamble
    <<~SH
      set -e
      export WORKDIR=$(mktemp -d)
      export V=$WORKDIR/test.gemv
      cp /gem/spec/fixtures/legacy-v2.gemv $V
      #{FixtureScript.gem_builds(gems: [["newcomer", "1.0.0"]], files: {}, dependencies: {})}
      export NEW_GEM=$WORKDIR/gems/newcomer/newcomer-1.0.0.gem
    SH
  end

  def run_on_dbvault(command:)
    podman_run(<<~SH)
      #{dbvault_preamble}
      #{command}
    SH
  end

  # Copies the committed legacy (format-1 SQLite) vault fixture into the
  # container. Reading it still requires the sqlite3 gem (installed in the
  # test image); no gem-building or SQLite writing happens at test time.
  def dbvault_preamble
    <<~SH
      set -e
      export WORKDIR=$(mktemp -d)
      export V=$WORKDIR/test.gemv
      cp /gem/spec/fixtures/legacy-v1.gemv $V
    SH
  end
end

RSpec.configure do |config|
  config.include UpgradeCommand, :integration
end
