require "rubygems/version"

module Gemvault
  ##
  # The role shared by every reference to a gem in a vault: it decides whether
  # it +matches?+ a given GemEntry. Two value objects play the role --
  # AnyVersion (no version constraint) and SpecificVersion (an exact
  # Gem::Version). +parse+ is the factory that turns raw CLI input into one of
  # them. Included as a module rather than subclassed so the players stay plain
  # Data value objects (equality, hashing, and deconstruction come for free).
  module GemReference
    class NonExactVersionError < StandardError; end

    ##
    # Whether this reference selects +gem+ (a GemEntry). Each player implements
    # it; the role itself declares the contract.
    def matches?(_gem)
      raise NotImplementedError, "#{self.class} must implement #matches?"
    end

    class << self
      def parse(input, version: nil)
        name = base_name(input)
        version_string = version || embedded_version(input)
        return AnyVersion.new(name: name) if version_string.nil?
        unless Gem::Version.correct?(version_string)
          raise NonExactVersionError, "Version must be an exact version (got: #{version_string.inspect})"
        end

        SpecificVersion.new(name: name, version: Gem::Version.new(version_string))
      end

      private

      def base_name(input)
        boundary = version_boundary(input)
        boundary ? input[0...boundary] : input
      end

      def embedded_version(input)
        boundary = version_boundary(input)
        boundary && input[(boundary + 1)..]
      end

      def version_boundary(input)
        idx = input.rindex("-")
        idx if idx && Gem::Version.correct?(input[(idx + 1)..])
      end
    end
  end
end

require_relative "gem_reference/any_version"
require_relative "gem_reference/specific_version"
