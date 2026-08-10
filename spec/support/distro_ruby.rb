# Script fragments that reshape the container's ruby to match environments
# seen in the wild: users may or may not have gemvault installed system-wide,
# and bundler may have been reinstalled over the packaged copy.
module DistroRuby
  # The base image is already a distro ruby, so bundler is already a regular
  # gem; this only reinstalls it in place, from the cache .gem that pinning
  # bundler at image build left behind. The line that used to delete a default
  # bundler gemspec is gone -- it named the official ruby image's gem layout,
  # which no longer exists in the container.
  def self.regular_bundler
    <<~SH
      gem install --local --force --no-document "$(ruby -e 'print Gem::Specification.find_by_name(%q{bundler}).cache_file')" >/dev/null
    SH
  end

  # gemvault and the dependencies only gemvault brings, so the plugin root has
  # to carry them itself.
  def self.without_system_gemvault
    "gem uninstall -x -a -I bundler-source-vault gemvault command_kit >/dev/null 2>&1 || true\n"
  end

  # A gemvault newer than the one the shim was released against, left on the
  # machine the way an upgrade or a stray `gem install` would. It is sabotaged
  # so that loading it is loud rather than silent: the shim pins an exact
  # version, and picking the newest instead has to fail the spec, not merely
  # run different code that happens to behave the same.
  def self.newer_gemvault_alongside
    <<~SH
      rm -rf /work/newer && mkdir -p /work/newer
      cp -r /gem/lib /gem/exe /gem/gemvault.gemspec /gem/README.md /gem/LICENSE.txt /gem/Rakefile /work/newer/
      sed -i 's/VERSION = ".*"/VERSION = "9.9.9"/' /work/newer/lib/gemvault/version.rb
      echo 'raise "the wrong gemvault was loaded"' >> /work/newer/lib/bundler/plugin/vault_source.rb
      (cd /work/newer && gem build -q gemvault.gemspec -o /work/newer/gemvault-9.9.9.gem >/dev/null 2>&1)
      gem install --no-document --local /work/newer/gemvault-9.9.9.gem >/dev/null 2>&1
    SH
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
