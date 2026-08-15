# A machine whose newest installed json outruns the version a project locks:
# the shape of issue #25, where any require of json ahead of Bundler's setup
# activates the newer copy and Bundler::Runtime#check_for_activated_spec!
# then refuses the older one the lockfile names.
module JsonVersionSkew
  LOCKED = "2.19.7".freeze
  NEWEST = "2.21.2".freeze

  # Stand-ins rather than the real gem: the scenario turns on which version is
  # activated, and a gem named json is enough to be activated. A loaded
  # stand-in announces itself so a require this suite did not expect shows up
  # in the scenario's output.
  def self.stub_gem(version)
    <<~SH
      mkdir -p /work/json-#{version}/lib
      cat > /work/json-#{version}/lib/json.rb <<'JSON_RB'
      warn "json #{version} stand-in loaded"
      module JSON
      end
      JSON_RB
      cat > /work/json-#{version}/json.gemspec <<'GEMSPEC'
      Gem::Specification.new do |s|
        s.name = "json"
        s.version = "#{version}"
        s.summary = "json stand-in"
        s.authors = ["gemvault spec"]
        s.license = "MIT"
        s.homepage = "https://example.com"
        s.files = ["lib/json.rb"]
      end
      GEMSPEC
      (cd /work/json-#{version} && gem build -q json.gemspec >/dev/null)
    SH
  end

  # Dropped beside the tree's own gems before the index is generated, so the
  # project can lock it and the bundle can install it.
  def self.older_in_index
    <<~SH
      #{stub_gem(LOCKED)}
      mkdir -p /work/src
      cp /work/json-#{LOCKED}/json-#{LOCKED}.gem /work/src/
    SH
  end

  # Installed the way a stray `gem install json` or another tool's dependency
  # leaves one: newest wins any require that resolves outside the bundle.
  def self.newer_installed
    <<~SH
      #{stub_gem(NEWEST)}
      gem install --local --no-document /work/json-#{NEWEST}/json-#{NEWEST}.gem >/dev/null
    SH
  end

  # Fedora unbundles json into the ruby stdlib directory, where a plain
  # require finds it without ever consulting gem activation; the reported
  # machine's rbenv ruby registers it as a default gem instead, so require
  # activates the newest installed copy -- issue #25's detonator. Clearing the
  # stdlib copy puts this machine in the reported shape.
  def self.resolved_through_activation
    <<~SH
      for dir in $(ruby -e 'puts $LOAD_PATH'); do rm -rf "$dir/json.rb" "$dir/json"; done
    SH
  end
end
