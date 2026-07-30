module NewCommand
  def run_new(args)
    podman_run(new_script(args, followup: ""))
  end

  def run_new_then(args, followup:)
    podman_run(new_script(args, followup: followup))
  end

  # `|| exit $?` hands the container gemvault's own exit status, so a spec can
  # assert on it; a followup only runs once the vault was created.
  def new_script(args, followup:)
    <<~SH
      export WORKDIR=$(mktemp -d)
      cd $WORKDIR
      gemvault new #{args} || exit $?
      #{followup}
    SH
  end
end

RSpec.configure do |config|
  config.include NewCommand, :integration
end
