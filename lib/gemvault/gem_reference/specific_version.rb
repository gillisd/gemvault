module Gemvault
  class GemReference
    # Matches one exact version of a named gem. `version:` is always a
    # Gem::Version (never nil, never a String) `.parse` validates and
    # constructs it before calling `.new`.
    class SpecificVersion < GemReference
      attr_reader :version

      def initialize(name:, version:)
        super(name: name)
        @version = version
      end

      def ==(other)
        super && version == other.version
      end
      alias eql? ==

      def hash
        [self.class, name, version].hash
      end

      def deconstruct_keys(keys)
        data = { name: name, version: version }
        keys.nil? ? data : data.slice(*keys)
      end
    end
  end
end
