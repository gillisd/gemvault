require_relative "shell"

# The cached podman image the integration specs run inside: building it,
# checking for it, and tearing it down. ContainerHelper owns running containers
# from it; this owns the image itself.
class ContainerImage
  # Building this image pulls a base image over the network and starts a
  # container to run the Dockerfile's layers, so it fails for reasons that have
  # nothing to do with gemvault. On 2026-07-29 a runner's crun refused to create
  # the container for the `dnf install` layer ("unknown version specified"),
  # reddening both integration jobs on two consecutive runs; the identical
  # commit then built cleanly on rerun with the same runner image, the same
  # podman and the same base-image digest.
  #
  # Nothing in the exit status distinguishes that from a real Dockerfile error,
  # so every failure is retried and every retry is announced. A genuinely broken
  # Dockerfile still fails the build -- it just takes ATTEMPTS tries to say so,
  # and such a failure is fast because it never reaches the network.
  ATTEMPTS = 3

  class Error < StandardError; end

  def initialize(name:, root:, digest:, shell: Shell.new, log: $stdout)
    @name = name
    @root = root
    @digest = digest
    @shell = shell
    @log = log
  end

  def exists?
    @shell.run("podman", "image", "exists", @name, silent: true)
  end

  def build
    1.upto(ATTEMPTS) { |attempt| return true if built_on_attempt?(attempt) }

    raise Error, "podman build of #{@name} failed after #{ATTEMPTS} attempts"
  end

  # What `rake spec:setup` wants: the image present, without paying to rebuild
  # one that already is.
  def ensure_built
    build unless exists?
  end

  # Idempotent so that `rake clobber` and a teardown of a tree that never built
  # the image both stay quiet.
  def destroy
    return false unless exists?

    remove_containers
    @shell.run("podman", "rmi", @name) || raise(Error, "podman rmi of #{@name} failed")
  end

  private

  def built_on_attempt?(attempt)
    command = build_command
    @log.puts command.join(" ")
    return true if @shell.run(*command)

    @log.puts "#{@name} build attempt #{attempt} of #{ATTEMPTS} failed; retrying" unless attempt == ATTEMPTS
    false
  end

  # The digest goes in as a build arg because Dockerfile.test reads the tree
  # through a bind mount, whose contents podman does not fold into its layer
  # cache key. It is what makes a build notice that the source changed.
  def build_command
    ["podman", "build", "--network=host", "-v", "#{@root}:/src:ro,z",
     "--build-arg", "SOURCE_DIGEST=#{@digest}",
     "-t", @name, "-f", "Dockerfile.test", "."]
  end

  def remove_containers
    strays = @shell.capture("podman", "ps", "-aq", "--filter", "ancestor=#{@name}").split
    return if strays.empty?

    @shell.run("podman", "rm", "-f", *strays) || raise(Error, "podman rm of #{@name} containers failed")
  end
end
