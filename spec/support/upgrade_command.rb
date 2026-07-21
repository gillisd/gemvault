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
      #{FixtureScript.preamble(gems: gems)}
      gemvault upgrade $WORKDIR/test.gemv #{upgrade_args}
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
