module Gemvault
  # Value object for one gem's identity (name, version, platform) and the time
  # it was stored in a vault. Equality, hashing, and to_h come from Data.
  class GemEntry < Data.define(:name, :version, :platform, :created_at)
    RUBY_PLATFORM_NAME = "ruby".freeze

    ##
    # Builds an entry from a <tt>Gem::Specification</tt> (or any object with
    # +name+, +version+, and +platform+), stringifying the version and platform.
    def self.from_spec(spec, created_at: nil)
      new(name: spec.name, version: spec.version.to_s, platform: spec.platform.to_s, created_at:)
    end

    def initialize(name:, version:, platform: RUBY_PLATFORM_NAME, created_at: nil)
      super
    end

    def ruby_platform? = platform == RUBY_PLATFORM_NAME

    def full_name
      ruby_platform? ? "#{name}-#{version}" : "#{name}-#{version}-#{platform}"
    end

    def filename = "#{full_name}.gem"

    def same_identity_as?(other)
      name == other.name && version == other.version && platform == other.platform
    end

    def to_s
      ruby_platform? ? "#{name}-#{version}" : "#{name}-#{version} (#{platform})"
    end
  end
end
