module FixtureScript
  # Generates a bash heredoc that creates a test gem and vault inside the container.
  # The vault is written to $WORKDIR/test.gemv. The gem is built in $WORKDIR/gems/.
  #
  # Options:
  #   gems: array of [name, version] pairs (default: one gem)
  #   files: hash of {name => {path => content}} overrides
  #   dependencies: hash of {name => [[dep_name, requirement]]}
  def self.preamble(gems: [["vault_test_gem", "1.0.0"]], files: {}, dependencies: {})
    gem_builds = gems.map { |name, version| build_gem(name, version, files, dependencies) }.join("\n")
    vault_adds = vault_add_commands(gems)

    <<~SH
      set -e
      export WORKDIR=$(mktemp -d)
      #{gem_builds}
      gemvault new $WORKDIR/test && #{vault_adds}
    SH
  end

  def self.build_gem(name, version, files, dependencies)
    gem_files = files.fetch(name, { "lib/#{name}.rb" => "module #{camelize(name)}; VERSION = \"#{version}\"; end" })
    deps = dependencies.fetch(name, [])

    <<~SH
      #{file_write_commands(name, gem_files)}
      cd $WORKDIR/gems/#{name} && cat > #{name}.gemspec <<'GEMSPEC'
      #{gemspec_body(name, version, gem_files, deps)}
      GEMSPEC
      gem build #{name}.gemspec 2>&1
    SH
  end

  def self.gemspec_body(name, version, gem_files, deps)
    dep_lines = deps.map { |dep_name, req| "s.add_dependency '#{dep_name}', '#{req}'" }.join("; ")

    <<~GEMSPEC.chomp
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
  end

  def self.file_write_commands(name, gem_files)
    gem_files.map { |path, content|
      "mkdir -p $(dirname $WORKDIR/gems/#{name}/#{path}) && " \
        "cat > $WORKDIR/gems/#{name}/#{path} <<'FILECONTENT'\n#{content}\nFILECONTENT"
    }.join("\n")
  end

  def self.vault_add_commands(gems)
    gems.map { |name, version|
      "gemvault add $WORKDIR/test.gemv $WORKDIR/gems/#{name}/#{name}-#{version}.gem"
    }.join(" && ")
  end

  def self.camelize(name)
    name.split(/[-_]/).map(&:capitalize).join
  end
end
