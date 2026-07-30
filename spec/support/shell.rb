require "open3"

# Runs a command as a subprocess, with no shell in between. Injected into
# ContainerImage so its retry behaviour can be specified without podman.
class Shell
  # `system` answers nil when the command cannot be executed at all and false
  # when it ran and failed. Both are failure here, and a caller that wants to
  # tell them apart has the exit status.
  def run(*command, silent: false)
    system(*command, **redirects(silent)) || false
  end

  def capture(*command)
    Open3.capture2(*command).first
  end

  private

  def redirects(silent)
    return {} unless silent

    { out: File::NULL, err: File::NULL }
  end
end
