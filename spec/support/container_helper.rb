require "open3"

module ContainerHelper
  BASE_IMAGE = "docker.io/library/ruby:4.0.1-slim".freeze
  CACHED_IMAGE = "gemvault-test:latest".freeze

  def podman_run(script)
    image = cached_image_available? ? CACHED_IMAGE : BASE_IMAGE
    cmd = [
      "podman", "run", "--rm", "--network=host",
      "-v", "#{project_root}:/gem:ro",
      image,
      "bash", "-c", script
    ]
    Open3.capture2e(*cmd)
  end

  private

  def project_root
    File.expand_path("../..", __dir__)
  end

  def cached_image_available?
    system("podman", "image", "exists", CACHED_IMAGE, out: File::NULL, err: File::NULL)
  end
end
