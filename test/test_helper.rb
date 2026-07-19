require "minitest/reporters"
require "minitest/autorun"
require "fileutils"
require "gemvault"
require "tmpdir"
require "open3"
require_relative "support/gem_factory"

Minitest::Reporters.use!

# Shared helpers mixed into the gemvault test cases.
module GemvaultTestHelper
  # Build a real .gem file programmatically.
  #
  # @param name [String] gem name
  # @param version [String] gem version
  # @param options [Hash] forwarded to GemFactory (dir:, platform:, files:, dependencies:)
  # @return [Pathname] absolute path to the built .gem file
  def build_gem(name:, version:, **options)
    GemFactory.new(name: name, version: version, **options).build
  end

  def gem_entry(name:, version:)
    Gemvault::GemEntry.new(name: name, version: version)
  end
end
