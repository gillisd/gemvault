module Gemvault
  class GemEntry
    attr_reader :name, :version, :platform, :created_at

    def initialize(name:, version:, platform: "ruby", created_at: nil)
      @name = name
      @version = version
      @platform = platform
      @created_at = created_at
    end

    def full_name
      platform == "ruby" ? "#{name}-#{version}" : "#{name}-#{version}-#{platform}"
    end

    def filename
      "#{full_name}.gem"
    end

    def to_s
      platform == "ruby" ? "#{name}-#{version}" : "#{name}-#{version} (#{platform})"
    end

    def ==(other)
      other.is_a?(self.class) &&
        name == other.name &&
        version == other.version &&
        platform == other.platform
    end

    alias eql? ==

    def hash
      [name, version, platform].hash
    end
  end
end
