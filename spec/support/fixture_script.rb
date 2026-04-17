module FixtureScript
  # Generates a bash heredoc that creates a test gem and vault inside the container.
  # The vault is written to $WORKDIR/test.gemv. The gem is built in $WORKDIR/gems/.
  #
  # Options:
  #   gems: array of [name, version] pairs (default: one gem)
  #   files: hash of {name => {path => content}} overrides
  #   dependencies: hash of {name => [[dep_name, requirement]]}
  def self.preamble(gems: [["vault_test_gem", "1.0.0"]], files: {}, dependencies: {})
    gem_builds = gems.map { |name, version|
      gem_files = files.fetch(name, {"lib/#{name}.rb" => "module #{camelize(name)}; VERSION = \"#{version}\"; end"})
      deps = dependencies.fetch(name, [])

      file_writes = gem_files.map { |path, content|
        "mkdir -p $(dirname $WORKDIR/gems/#{name}/#{path}) && " \
          "echo '#{content}' > $WORKDIR/gems/#{name}/#{path}"
      }.join(" && ")

      dep_lines = deps.map { |dep_name, req| "s.add_dependency '#{dep_name}', '#{req}'" }.join("; ")

      <<~SH
        #{file_writes}
        cd $WORKDIR/gems/#{name} && cat > #{name}.gemspec <<'GEMSPEC'
        Gem::Specification.new do |s|
          s.name = "#{name}"
          s.version = "#{version}"
          s.summary = "test"
          s.authors = ["test"]
          s.license = "MIT"
          s.homepage = "https://example.com"
          s.files = #{gem_files.keys.inspect}
          #{dep_lines}
        end
        GEMSPEC
        gem build #{name}.gemspec 2>&1
      SH
    }.join("\n")

    vault_adds = gems.map { |name, version|
      "gemvault add $WORKDIR/test.gemv $WORKDIR/gems/#{name}/#{name}-#{version}.gem"
    }.join(" && ")

    <<~SH
      set -e
      export WORKDIR=$(mktemp -d)
      #{gem_builds}
      gemvault new $WORKDIR/test && #{vault_adds}
    SH
  end

  def self.camelize(name)
    name.split(/[-_]/).map(&:capitalize).join
  end
end
