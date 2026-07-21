require "rubygems/version"

module Gemvault
  ##
  # The role shared by every reference to a gem in a vault: it decides whether
  # it +matches?+ a given GemEntry. Two value objects play the role --
  # AnyVersion (no version constraint) and SpecificVersion (an exact
  # Gem::Version). Players +include GemReference+ to declare the role; the
  # +matches?+ contract is enforced by the "a gem reference" shared examples.
  # +parse+ is the factory that turns raw CLI input into a player.
  module GemReference
    class NonExactVersionError < StandardError; end

    def self.parse(input, version: nil)
      Parser.new(input:, version:).call
    end
  end
end

require_relative "gem_reference/parser"
require_relative "gem_reference/any_version"
require_relative "gem_reference/specific_version"
