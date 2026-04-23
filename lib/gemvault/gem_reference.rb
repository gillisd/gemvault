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
      base_name, embedded = split_name_version(input)
      version_string = version || embedded
      return AnyVersion.new(name: base_name) if version_string.nil?
      unless Gem::Version.correct?(version_string)
        raise NonExactVersionError, "Version must be an exact version (got: #{version_string.inspect})"
      end

      SpecificVersion.new(name: base_name, version: Gem::Version.new(version_string))
    end

    def self.split_name_version(input)
      idx = input.rindex("-")
      return [input, nil] unless idx && Gem::Version.correct?(input[(idx + 1)..])

      [input[0...idx], input[(idx + 1)..]]
    end
    private_class_method :split_name_version

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
