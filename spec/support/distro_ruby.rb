# Script fragments that reshape the container's ruby to match environments
# seen in the wild: users may or may not have gemvault installed system-wide,
# and bundler may have been reinstalled over the packaged copy.
module DistroRuby
  # The base image is already a distro ruby, so bundler is already a regular
  # gem; this only reinstalls it in place over the packaged copy. The line that
  # used to delete a default bundler gemspec is gone -- it named the official
  # ruby image's gem layout, which no longer exists in the container.
  def self.regular_bundler
    "gem install --local --force --no-document /opt/gems/bundler-*.gem >/dev/null\n"
  end

  def self.without_system_gemvault
    "gem uninstall -x -a -I bundler-source-vault gemvault command_kit >/dev/null 2>&1 || true\n"
  end

  # Installs the tree's gemvault as a system gem without the shim, the shape of
  # a machine where the user ran `gem install gemvault` for the CLI.
  def self.gemvault_as_a_system_gem
    "gem install --local --force --no-document /work/src/gemvault-*.gem >/dev/null\n"
  end

  # Replaces the image's baked-in gemvault gems with ones freshly built from
  # the mounted source tree (requires TreeGems.build_preamble to have run).
  def self.current_tree_as_system_gems
    <<~SH
      gem install --local --force --no-document /work/src/gemvault-*.gem >/dev/null
      gem install --local --force --no-document /work/src/shim/bundler-source-vault-*.gem >/dev/null
    SH
  end
end
