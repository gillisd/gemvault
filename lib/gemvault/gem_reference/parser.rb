require "rubygems/version"

module Gemvault
  module GemReference
    ##
    # Turns raw CLI input into the GemReference that selects it. Input is either
    # a bare name ("foo") or a combined NAME-VERSION ("foo-1.2.3"); an explicit
    # +version+ overrides any version embedded in the input. A name and version
    # yield a SpecificVersion, a lone name an AnyVersion, and a non-exact version
    # a NonExactVersionError.
    class Parser < Data.define(:input, :version)
      def initialize(input:, version: nil) = super

      def call
        boundary = version_boundary
        name = boundary ? input[0...boundary] : input
        embedded_version = boundary && input[(boundary + 1)..]
        build(name:, version_string: version || embedded_version)
      end

      private

      def build(name:, version_string:)
        return AnyVersion.new(name:) if version_string.nil?

        raise_non_exact(version_string) unless Gem::Version.correct?(version_string)

        SpecificVersion.new(name:, version: Gem::Version.new(version_string))
      end

      def version_boundary
        hyphen = input.rindex("-")
        return nil unless hyphen

        trailing = input[(hyphen + 1)..]
        hyphen if Gem::Version.correct?(trailing)
      end

      def raise_non_exact(version_string)
        raise NonExactVersionError, "Version must be an exact version (got: #{version_string.inspect})"
      end
    end
  end
end
