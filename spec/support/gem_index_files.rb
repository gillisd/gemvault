# Renders the files a gem index is made of, from the .gem files in the index's
# gems/ directory. Run inside the container by GemIndex.serve_preamble.
#
# Both index protocols are written. Bundler against rubygems.org speaks the
# compact index (/versions, /info/NAME), and only that path materializes
# remote specifications the way a user's machine does -- resolving through
# the legacy marshal index alone is what kept issue #23 invisible to this
# suite. The marshal files stay because `gem install --source` still reads
# them. Formats follow the compact_index reference implementation:
#
#   versions:   created_at: TIME
#               ---
#               NAME V1[,V2] MD5-of-info-file
#   info/NAME:  ---
#               VERSION[-PLATFORM] DEP:REQ[&REQ][,DEP:REQ]|checksum:HEX[,ruby:REQ][,rubygems:REQ],created_at:TIME
#
# Every info line carries created_at because rubygems.org's does: Bundler's
# cooldown machinery backfills that date onto matching installed stubs and
# attaches the remote to them (Source::Rubygems#backfill_created_at), which
# is the very path that turns a ghost specification into issue #23. An index
# without created_at resolves the same gems while silently skipping that
# path.
module GemIndexFiles
  MKINDEX_RB = <<~'RUBY'.freeze
    require "rubygems/package"
    require "zlib"
    require "digest"
    require "pathname"

    def marshal_gz(payload) = Zlib.gzip(Marshal.dump(payload))
    def marshal_rz(payload) = Zlib::Deflate.deflate(Marshal.dump(payload))

    def version_token(spec) = spec.platform.to_s == "ruby" ? spec.version.to_s : "#{spec.version}-#{spec.platform}"

    def requirement_token(requirement) = requirement.requirements.map { |op, v| "#{op} #{v}" }.join("&")

    def dependency_tokens(spec)
      spec.runtime_dependencies.sort_by(&:name).map { |dep| "#{dep.name}:#{requirement_token(dep.requirement)}" }.join(",")
    end

    def constraint_tokens(spec, gem_file)
      tokens = ["checksum:#{Digest::SHA256.file(gem_file.to_s).hexdigest}"]
      tokens << "ruby:#{requirement_token(spec.required_ruby_version)}" unless spec.required_ruby_version.none?
      tokens << "rubygems:#{requirement_token(spec.required_rubygems_version)}" unless spec.required_rubygems_version.none?
      tokens << "created_at:2026-01-01T00:00:00Z"
      tokens.join(",")
    end

    def info_content(releases)
      lines = releases.map { |spec, gem_file| "#{version_token(spec)} #{dependency_tokens(spec)}|#{constraint_tokens(spec, gem_file)}" }
      "---\n#{lines.join("\n")}\n"
    end

    index = Pathname(ARGV.first)
    packaged = index.join("gems").glob("*.gem").map { |gem_file| [Gem::Package.new(gem_file.to_s).spec, gem_file] }
    specs = packaged.map(&:first)
    entries = specs.map { |spec| [spec.name, spec.version, spec.platform.to_s] }

    ["specs.4.8.gz", "latest_specs.4.8.gz"].each { |name| index.join(name).binwrite(marshal_gz(entries)) }
    index.join("prerelease_specs.4.8.gz").binwrite(marshal_gz([]))

    quick = index.join("quick", "Marshal.4.8").tap(&:mkpath)
    specs.each { |spec| quick.join("#{spec.original_name}.gemspec.rz").binwrite(marshal_rz(spec)) }

    info_dir = index.join("info").tap(&:mkpath)
    by_name = packaged.group_by { |spec, _| spec.name }.sort_by(&:first)
    by_name.each { |name, releases| info_dir.join(name).write(info_content(releases)) }

    versions_lines = by_name.map do |name, releases|
      "#{name} #{releases.map { |spec, _| version_token(spec) }.join(",")} #{Digest::MD5.hexdigest(info_content(releases))}"
    end
    index.join("versions").write("created_at: 2026-01-01T00:00:00Z\n---\n#{versions_lines.join("\n")}\n")
    index.join("names").write("---\n#{by_name.map(&:first).join("\n")}\n")
  RUBY
end
