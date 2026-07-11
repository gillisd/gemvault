module UpgradeCommand
  def run_upgrade(gems:, upgrade_args: "", followup: "")
    podman_run(<<~SH)
      #{dbvault_preamble(gems)}
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

  def dbvault_preamble(gems)
    gem_builds = gems.map { |name, version| FixtureScript.build_gem(name, version, {}, {}) }.join("\n")
    paths = gems.map { |name, version| "$WORKDIR/gems/#{name}/#{name}-#{version}.gem" }.join(" ")
    <<~SH
      set -e
      export WORKDIR=$(mktemp -d)
      export V=$WORKDIR/test.gemv
      #{gem_builds}
      ruby -e 'require "gemvault/dbvault"; Gemvault::Dbvault.open(ENV["V"], create: true){|v| ARGV.each{|g| v.add(g)}}' #{paths}
    SH
  end
end

RSpec.configure do |config|
  config.include UpgradeCommand, :integration
end
