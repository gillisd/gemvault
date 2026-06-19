module RemoveCommand
  def run_remove(gems:, remove_args:, followup: "")
    podman_run(remove_script(gems, remove_args, followup))
  end

  def remove_with_version_override
    run_remove(
      gems: [["foo", "1.0.0"], ["foo", "2.0.0"]],
      remove_args: "foo-1.0.0 --version 2.0.0",
      followup: "gemvault list $WORKDIR/test.gemv",
    )
  end

  def remove_script(gems, remove_args, followup)
    preamble = FixtureScript.preamble(gems: gems)
    <<~SH
      #{preamble}
      gemvault remove $WORKDIR/test.gemv #{remove_args}
      #{followup}
    SH
  end
end

RSpec.configure do |config|
  config.include RemoveCommand, :integration
end
