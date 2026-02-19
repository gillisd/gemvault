# frozen_string_literal: true

require "minitest/autorun"
require "gemvault"
require "tmpdir"
require "fileutils"
require "open3"

module GemvaultTestHelper
  # Build a real .gem file programmatically.
  #
  # @param name [String] gem name
  # @param version [String] gem version
  # @param dir [String] directory to build the gem in
  # @param platform [String, nil] optional platform (e.g. "x86_64-linux")
  # @param files [Hash{String => String}, nil] files to include (path => content)
  # @param dependencies [Array<Array(String, String)>] gem dependencies
  # @return [String] absolute path to the built .gem file
  def build_gem(name, version, dir:, platform: nil, files: nil, dependencies: [])
    files ||= { "lib/#{name}.rb" => "module #{name.split('-').map(&:capitalize).join}; end" }

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
      full = File.join(dir, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
    end

    gem_file = Dir.chdir(dir) { Gem::Package.build(spec, true) }
    File.join(dir, gem_file)
  end
end
