module Gemvault
  module GemReference
    ##
    # Matches one exact version of a named gem. +version+ is always a
    # Gem::Version (never nil, never a String); GemReference.parse validates and
    # constructs it before calling .new.
    class SpecificVersion < Data.define(:name, :version)
      include GemReference

      def matches?(gem) = gem.name == name && gem.version == version.to_s
    end
  end
end
