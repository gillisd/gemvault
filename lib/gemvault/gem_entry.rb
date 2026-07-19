module Gemvault
  # Value object for one gem's identity (name, version, platform) and the time
  # it was stored in a vault. Equality, hashing, and to_h come from Data.
  class GemEntry < Data.define(:name, :version, :platform, :created_at)
    def initialize(name:, version:, platform: "ruby", created_at: nil)
      super
    end

    def full_name
      platform == "ruby" ? "#{name}-#{version}" : "#{name}-#{version}-#{platform}"
    end

    def filename = "#{full_name}.gem"

    def same_identity_as?(other)
      name == other.name && version == other.version && platform == other.platform
    end

    def to_s
      platform == "ruby" ? "#{name}-#{version}" : "#{name}-#{version} (#{platform})"
    end
  end
end
