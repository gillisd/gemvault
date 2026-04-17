require "minitest/autorun"
require "fileutils"
require "gemvault"
require "tmpdir"
require "open3"

module GemvaultTestHelper
  # Build a real .gem file programmatically.
  #
  # @param name [String] gem name
  # @param version [String] gem version
  # @param dir [Pathname, String] directory to build the gem in
  # @param platform [String, nil] optional platform (e.g. "x86_64-linux")
  # @param files [Hash{String => String}, nil] files to include (path => content)
  # @param dependencies [Array<Array(String, String)>] gem dependencies
  # @return [Pathname] absolute path to the built .gem file
  def build_gem(name, version, dir:, platform: nil, files: nil, dependencies: [])
    dir = Pathname(dir)
    files ||= { "lib/#{name}.rb" => "module #{name.split("-").map(&:capitalize).join}; end" }

    spec = Gem::Specification.new do |s|
      s.name = name
      s.version = version
      s.summary = "Test gem"
      s.authors = ["Test"]
      s.homepage = "https://example.com"
      s.license = "MIT"
      s.platform = platform if platform
      files.each_key { |f| s.files << f }
      dependencies.each { |dep, req| s.add_dependency(dep, req) }
    end

    files.each do |path, content|
      full = dir / path
      full.dirname.mkpath
      full.write(content)
    end

    gem_file = Dir.chdir(dir) { Gem::Package.build(spec, true) }
    dir / gem_file
  end
end
