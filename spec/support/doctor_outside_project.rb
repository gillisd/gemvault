module DoctorOutsideProject
  # Doctor run from the wrong directory: no Gemfile, no project-owned plugin
  # root, so the uninstall works against bundler's global index and nothing
  # project-local may be claimed repaired.
  def run_doctor_outside_any_project
    podman_run(<<~SH)
      set -e
      cd $(mktemp -d)
      gemvault doctor
    SH
  end
end

RSpec.configure do |config|
  config.include DoctorOutsideProject, :integration
end
