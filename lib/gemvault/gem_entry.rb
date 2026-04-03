# frozen_string_literal: true

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
      self.class === other &&
        name == other.name &&
        version == other.version &&
        platform == other.platform
    end

    alias_method :eql?, :==

    def hash
      [name, version, platform].hash
    end
  end
end
