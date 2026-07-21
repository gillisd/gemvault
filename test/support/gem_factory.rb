require "rubygems/package"

# Builds real `.gem` files on disk for use as test fixtures.
#
# Encapsulates the Gem::Specification construction, fixture file writing,
# and packaging so test helpers can request a gem with a single call.
class GemFactory
  def initialize(name:, version:, dir:, **spec_options)
    @name = name
    @version = version
    @dir = Pathname(dir)
    @platform = spec_options[:platform]
    @files = spec_options[:files] || default_files
    @dependencies = spec_options[:dependencies] || []
  end

  # @return [Pathname] absolute path to the built .gem file
  def build
    write_fixture_files
    gem_file = Dir.chdir(@dir) { Gem::Package.build(specification, true) }
    @dir / gem_file
  end

  private

  def default_files
    { "lib/#{@name}.rb" => "module #{module_name}; end" }
  end

  def module_name
    @name.split("-").map(&:capitalize).join
  end

  def specification
    spec = Gem::Specification.new
    apply_metadata(spec)
    spec.platform = @platform if @platform
    @files.each_key { |path| spec.files << path }
    @dependencies.each { |dep, requirement| spec.add_dependency(dep, requirement) }
    spec
  end

  def apply_metadata(spec)
    spec.name = @name
    spec.version = @version
    spec.summary = "Test gem"
    spec.authors = ["Test"]
    spec.homepage = "https://example.com"
    spec.license = "MIT"
  end

  def write_fixture_files
    @files.each do |path, content|
      full = @dir / path
      full.dirname.mkpath
      full.write(content)
    end
  end
end
