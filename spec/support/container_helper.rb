require "open3"

module ContainerHelper
  # Dockerfile.test builds a distro ruby, which needs no environment surgery to
  # look like a user's machine: nothing is exported, gems land in RubyGems' own
  # default dirs, and bundler is a regular gem. There is no usable fallback
  # image -- running against a stock ruby image is what hid issues #12 and #13.
  CACHED_IMAGE = "gemvault-test:latest".freeze

  # A script fully determines its run: the container is --rm and every scenario
  # makes its own mktemp workdir, so running one twice observes nothing new.
  # RSpec memoizes `let` per example rather than per context, so a scenario
  # asserted by several examples would otherwise boot a container per example.
  def self.completed_runs
    @completed_runs ||= {}
  end

  # Not a fallback -- there is deliberately no second image to fall back to.
  # Without this, running rspec outside the rake tasks that build the image
  # fails every integration example with podman's short-name resolution error.
  def self.image_available?
    return @image_available unless @image_available.nil?

    @image_available = system("podman", "image", "exists", CACHED_IMAGE, out: File::NULL, err: File::NULL)
  end

  def podman_run(script)
    unless ContainerHelper.image_available?
      raise "#{CACHED_IMAGE} has not been built. Run `rake spec:build`, or use `rake spec` / `rake spec:integration`."
    end

    ContainerHelper.completed_runs[script] ||= capture_container(script)
  end

  private

  def capture_container(script)
    Open3.capture2e(
      "podman", "run", "--rm", "--network=host",
      "-v", "#{project_root}:/gem:ro",
      CACHED_IMAGE,
      "bash", "-c", script
    )
  end

  def project_root
    File.expand_path("../..", __dir__)
  end
end
