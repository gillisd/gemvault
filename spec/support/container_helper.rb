require "open3"

module ContainerHelper
  # Dockerfile.test builds a distro ruby, which needs no environment surgery to
  # look like a user's machine: nothing is exported, gems land in RubyGems' own
  # default dirs, and bundler is a regular gem. There is no usable fallback
  # image -- running against a stock ruby image is what hid issues #12 and #13.
  CACHED_IMAGE = "gemvault-test:latest".freeze

  def podman_run(script)
    cmd = [
      "podman", "run", "--rm", "--network=host",
      "-v", "#{project_root}:/gem:ro",
      CACHED_IMAGE,
      "bash", "-c", script
    ]
    Open3.capture2e(*cmd)
  end

  private

  def project_root
    File.expand_path("../..", __dir__)
  end
end
