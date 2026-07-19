require "rubygems/version"
require_relative "gem_reference/any_version"
require_relative "gem_reference/specific_version"

module Gemvault
  # A reference to a gem in a vault. Abstract base class for two concrete
  # kinds: AnyVersion (no version constraint) and SpecificVersion (an exact
  # Gem::Version). Not instantiable directly. `.parse` is the factory that
  # turns raw CLI input into one of the two subclasses.
  class GemReference
    class NonExactVersionError < StandardError; end

    def self.parse(input, version: nil)
      name = base_name(input)
      version_string = version || embedded_version(input)
      return AnyVersion.new(name: name) if version_string.nil?
      unless Gem::Version.correct?(version_string)
        raise NonExactVersionError, "Version must be an exact version (got: #{version_string.inspect})"
      end

      SpecificVersion.new(name: name, version: Gem::Version.new(version_string))
    end

    def self.base_name(input)
      boundary = version_boundary(input)
      boundary ? input[0...boundary] : input
    end
    private_class_method :base_name

    def self.embedded_version(input)
      boundary = version_boundary(input)
      boundary && input[(boundary + 1)..]
    end
    private_class_method :embedded_version

    def self.version_boundary(input)
      idx = input.rindex("-")
      idx if idx && Gem::Version.correct?(input[(idx + 1)..])
    end
    private_class_method :version_boundary

    attr_reader :name

    def initialize(name:)
      raise NotImplementedError, "abstract base use AnyVersion or SpecificVersion" if instance_of?(GemReference)

      @name = name
    end

    def ==(other)
      self.class == other.class && name == other.name
    end
    alias eql? ==

    def hash
      [self.class, name].hash
    end

    def deconstruct_keys(keys)
      data = { name: name }
      keys.nil? ? data : data.slice(*keys)
    end
  end
end
