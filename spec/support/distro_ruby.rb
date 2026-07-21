# Script fragments that reshape the container's ruby to match environments
# seen in the wild: distro rubies ship bundler as a regular gem rather than a
# default gem, and users may or may not have gemvault installed system-wide.
module DistroRuby
  def self.regular_bundler
    <<~SH
      gem install --local --force --no-document /opt/gems/bundler-*.gem >/dev/null
      rm -f /usr/local/lib/ruby/gems/*/specifications/default/bundler-*.gemspec
    SH
  end

  def self.without_system_gemvault
    "gem uninstall -x -a -I bundler-source-vault gemvault command_kit >/dev/null 2>&1 || true\n"
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
