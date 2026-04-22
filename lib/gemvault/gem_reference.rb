require "rubygems/version"
require_relative "gem_reference/any_version"
require_relative "gem_reference/specific_version"

module Gemvault
  # Namespace + factory for user-supplied gem references. `.parse` returns
  # an AnyVersion (no version constraint) or a SpecificVersion (exact
  # Gem::Version). Ranged strings raise NonExactVersionError.
  module GemReference
    class NonExactVersionError < StandardError; end

    def self.parse(input, version: nil)
      idx = input.rindex("-")
      tail = idx && input[(idx + 1)..]
      split = idx && Gem::Version.correct?(tail)
      build(split ? input[0...idx] : input, version || (split ? tail : nil))
    end

    def self.build(name, version_string)
      return AnyVersion.new(name: name) if version_string.nil?
      unless Gem::Version.correct?(version_string)
        raise NonExactVersionError, "Version must be an exact version (got: #{version_string.inspect})"
      end

      SpecificVersion.new(name: name, version: Gem::Version.new(version_string))
    end
    private_class_method :build
  end
end
